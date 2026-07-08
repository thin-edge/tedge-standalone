#!/usr/bin/env python3
"""Render a side-by-side memory comparison from measure.sh JSON result files.

Usage: summarize.py <result1.json> <result2.json> [...]
Each file's "version" field is used as its column label.
"""
import json, sys, os

paths = sys.argv[1:]
rows = []
for p in paths:
    if not os.path.exists(p):
        print(f"(missing result: {p})")
        continue
    with open(p) as f:
        rows.append(json.load(f))

if not rows:
    sys.exit("no results to summarize")

def mb(kb): return f"{kb/1024:.1f} MB"

# (json key, label). Rows with 0 across all results are hidden to reduce noise.
COLS = [
    ("remote_access_largest_proc_hwm_kb", "RA plugin peak (1 proc)"),
    ("remote_access_peak_hwm_kb",         "RA plugin peak (all procs)"),
    ("remote_access_peak_rss_kb",         "RA plugin RSS (all procs)"),
    ("remote_access_peak_pss_kb",         "RA plugin PSS (physical)"),
    ("remote_access_peak_anon_kb",        "RA plugin Anon (heap+dirty)"),
    ("remote_access_procs",               "RA plugin process count"),
    ("tedge_agent_peak_rss_kb",           "tedge-agent RSS"),
    ("tedge_mapper_peak_rss_kb",          "tedge-mapper RSS"),
    ("tedge_runall_peak_rss_kb",          "tedge run-all RSS"),
    ("mosquitto_peak_rss_kb",             "mosquitto RSS"),
    ("total_tedge_peak_rss_kb",           "total tedge RSS (overcounts)"),
    ("total_tedge_peak_pss_kb",           "total tedge PSS (physical)"),
]
COUNT_KEYS = {"remote_access_procs"}

def fmt(key, r):
    v = r.get(key, 0)
    return str(v) if key in COUNT_KEYS else mb(v)

labels = [r.get("version", "?") for r in rows]
w = max(28, *(len(l) for l in labels)) if labels else 28

print("\n================= Remote-access memory comparison =================")
hdr = f"{'metric':<30}" + "".join(f"{l:>18}" for l in labels)
print(hdr); print("-" * len(hdr))
for key, label in COLS:
    if all(int(r.get(key, 0) or 0) == 0 for r in rows):
        continue  # hide all-zero rows (e.g. run-all row when not testing run-all)
    print(f"{label:<30}" + "".join(f"{fmt(key, r):>18}" for r in rows))

if len(rows) == 2:
    a, b = rows
    print("-" * len(hdr))
    for key, label in (("remote_access_largest_proc_hwm_kb", "remote-access plugin (peak HWM, 1 proc)"),
                       ("total_tedge_peak_pss_kb",           "total footprint (PSS)")):
        av, bv = a.get(key, 0), b.get(key, 0)
        if av and bv:
            diff = av - bv
            pct = 100.0 * diff / bv
            verb = "MORE" if diff > 0 else "LESS"
            print(f"\n{labels[0]} uses {mb(abs(diff))} ({pct:+.0f}%) {verb} than "
                  f"{labels[1]} for {label}.")
print("==================================================================\n")
