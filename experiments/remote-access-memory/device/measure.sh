#!/bin/sh
# Sample the resident memory of the tedge process tree for a fixed duration and
# report the PEAK values. Intended to be run inside the device container while a
# Cumulocity remote-access session is active.
#
# Why VmHWM matters here: a upx-compressed binary decompresses its *entire* image
# into anonymous memory at exec() time, so the peak resident set (VmHWM) of the
# c8y-remote-access-plugin process is the headline number for this experiment.
#
# Usage: measure.sh [DURATION_SECONDS=20] [INTERVAL_SECONDS=0.2]
set -u

DURATION="${1:-20}"
INTERVAL="${2:-0.2}"

# All amounts are in kB (as reported by /proc/<pid>/status).
peak_remote_access_rss=0      # summed VmRSS of all remote-access processes
peak_remote_access_hwm=0      # summed VmHWM of all remote-access processes
peak_remote_access_one=0      # largest single remote-access process VmHWM
peak_remote_access_procs=0
peak_agent_rss=0
peak_mapper_rss=0
peak_mosquitto_rss=0
peak_total_rss=0              # whole tedge footprint (agent+mapper+mosquitto+plugin)

read_field() { # file field -> value in kB (0 if missing)
    awk -v f="$2" '$1==f":"{print $2; found=1} END{if(!found)print 0}' "$1" 2>/dev/null
}

category() { # cmdline -> category name ("" if not ours)
    case "$1" in
        *c8y-remote-access-plugin*) echo remote_access ;;
        *tedge-agent*)              echo agent ;;
        *tedge-mapper*)             echo mapper ;;
        *mosquitto*)                echo mosquitto ;;
        *) echo "" ;;
    esac
}

start=$(cut -d. -f1 /proc/uptime)
deadline=$((start + DURATION))

while :; do
    s_ra_rss=0; s_ra_hwm=0; s_ra_one=0; s_ra_n=0
    s_agent=0; s_mapper=0; s_mosq=0; s_total=0

    for statf in /proc/[0-9]*/status; do
        [ -r "$statf" ] || continue
        pid_dir=${statf%/status}
        cmd=$(tr '\0' ' ' < "$pid_dir/cmdline" 2>/dev/null)
        [ -n "$cmd" ] || continue
        cat=$(category "$cmd")
        [ -n "$cat" ] || continue

        rss=$(read_field "$statf" VmRSS)
        hwm=$(read_field "$statf" VmHWM)
        [ -n "$rss" ] || rss=0
        [ -n "$hwm" ] || hwm=0

        s_total=$((s_total + rss))
        case "$cat" in
            remote_access)
                s_ra_rss=$((s_ra_rss + rss))
                s_ra_hwm=$((s_ra_hwm + hwm))
                s_ra_n=$((s_ra_n + 1))
                [ "$hwm" -gt "$s_ra_one" ] && s_ra_one=$hwm
                ;;
            agent)     s_agent=$((s_agent + rss)) ;;
            mapper)    s_mapper=$((s_mapper + rss)) ;;
            mosquitto) s_mosq=$((s_mosq + rss)) ;;
        esac
    done

    [ "$s_ra_rss" -gt "$peak_remote_access_rss" ] && peak_remote_access_rss=$s_ra_rss
    [ "$s_ra_hwm" -gt "$peak_remote_access_hwm" ] && peak_remote_access_hwm=$s_ra_hwm
    [ "$s_ra_one" -gt "$peak_remote_access_one" ] && peak_remote_access_one=$s_ra_one
    [ "$s_ra_n"   -gt "$peak_remote_access_procs" ] && peak_remote_access_procs=$s_ra_n
    [ "$s_agent"  -gt "$peak_agent_rss" ] && peak_agent_rss=$s_agent
    [ "$s_mapper" -gt "$peak_mapper_rss" ] && peak_mapper_rss=$s_mapper
    [ "$s_mosq"   -gt "$peak_mosquitto_rss" ] && peak_mosquitto_rss=$s_mosq
    [ "$s_total"  -gt "$peak_total_rss" ] && peak_total_rss=$s_total

    now=$(cut -d. -f1 /proc/uptime)
    [ "$now" -ge "$deadline" ] && break
    sleep "$INTERVAL"
done

kb_mb() { awk -v v="$1" 'BEGIN{printf "%.1f", v/1024}'; }

cat <<EOF
{
  "version": "${STANDALONE_PKG_VERSION:-unknown}",
  "duration_s": ${DURATION},
  "remote_access_procs": ${peak_remote_access_procs},
  "remote_access_peak_rss_kb": ${peak_remote_access_rss},
  "remote_access_peak_hwm_kb": ${peak_remote_access_hwm},
  "remote_access_largest_proc_hwm_kb": ${peak_remote_access_one},
  "tedge_agent_peak_rss_kb": ${peak_agent_rss},
  "tedge_mapper_peak_rss_kb": ${peak_mapper_rss},
  "mosquitto_peak_rss_kb": ${peak_mosquitto_rss},
  "total_tedge_peak_rss_kb": ${peak_total_rss}
}
EOF

{
    echo "----------------------------------------------------------------"
    echo "  version .......................... ${STANDALONE_PKG_VERSION:-unknown}"
    echo "  remote-access processes seen ..... ${peak_remote_access_procs}"
    echo "  remote-access peak RSS (all) ..... $(kb_mb "$peak_remote_access_rss") MB (${peak_remote_access_rss} kB)"
    echo "  remote-access peak HWM (all) ..... $(kb_mb "$peak_remote_access_hwm") MB (${peak_remote_access_hwm} kB)"
    echo "  remote-access largest proc HWM ... $(kb_mb "$peak_remote_access_one") MB (${peak_remote_access_one} kB)"
    echo "  tedge-agent peak RSS ............. $(kb_mb "$peak_agent_rss") MB"
    echo "  tedge-mapper peak RSS ............ $(kb_mb "$peak_mapper_rss") MB"
    echo "  mosquitto peak RSS ............... $(kb_mb "$peak_mosquitto_rss") MB"
    echo "  total tedge peak RSS ............. $(kb_mb "$peak_total_rss") MB"
    echo "----------------------------------------------------------------"
} >&2
