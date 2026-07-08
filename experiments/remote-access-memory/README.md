# Remote-access memory experiment

Reproduce and measure the claim that **tedge-standalone `2.0.1-3` (tedge 2.0.1) uses
more memory for a Cumulocity remote-access connection than `0.11.0` (tedge 1.6.1)**.

## What it sets up

Two containers on one Docker network:

| Container    | Base                    | Role |
|--------------|-------------------------|------|
| `device`     | Alpine (busybox + musl) + **runit** + **openssh-client** | Runs the thin-edge.io standalone package under test, supervised by `runsvdir`, exactly like a real constrained device. |
| `ssh-server` | Alpine + **openssh-server** | The remote-access *target*. The device's `c8y-remote-access-plugin` bridges the Cumulocity websocket to `ssh-server:22`. |

The device registers against your **real Cumulocity tenant** using the Cumulocity
Certificate Authority (one-time-password enrollment — no manual cert upload).

### Why memory differs (the hypothesis)

`c8y-remote-access-plugin` is **not a separate binary** — it is a multicall entry of
the single `tedge` binary (invoked by `argv[0]`). In the standalone package that
binary is **upx-compressed**. A upx binary decompresses its *entire* image into
anonymous RAM at `exec()` time, so every time remote-access fires, the whole `tedge`
binary is faulted into memory. Between versions the binary grew (≈5.5 MB compressed
→ ≈16 MB uncompressed in 2.0.1), so the peak resident set of the plugin process is
expected to be larger. The experiment measures exactly this: the **peak `VmHWM`** of
the `c8y-remote-access-plugin` process while a tunnel is live.

## Prerequisites

- Docker (with `docker compose`)
- [`go-c8y-cli`](https://goc8ycli.netlify.app/) (`c8y`) for driving the cloud side
- `python3` (only for the comparison summary)
- Cumulocity credentials — the harness reads them from the repo-root `.env`
  (`C8Y_BASEURL`, `C8Y_USER`, `C8Y_PASSWORD`, `C8Y_TENANT`) or a local `.env` here
  (see `.env.example`).

## Run the full comparison

```sh
cd experiments/remote-access-memory
./scripts/run-experiment.sh              # 2.0.1-3 vs 0.11.0, upx builds
```

For each version this will: build the device image, start the containers, register
+ bootstrap the device against your tenant, open a remote-access session to
`ssh-server`, sample memory for ~15s, then tear the device down and delete it from
Cumulocity. At the end it prints a side-by-side table and the headline delta.

Useful variants:

```sh
VARIANT=-noupx ./scripts/run-experiment.sh          # compare the uncompressed builds
DURATION=30 ./scripts/run-experiment.sh             # sample longer
DELETE_DEVICE=0 ./scripts/run-experiment.sh         # keep the C8y devices afterwards
TEDGE_ARCH=amd64 ./scripts/run-experiment.sh        # x86 host
./scripts/run-experiment.sh 2.0.1-3 2.0.1-3         # A/B the same version (sanity)
```

## Run steps manually

```sh
# 1. Build + start one version
TEDGE_VERSION=2.0.1-3 docker compose up -d --build

# 2. Register + bootstrap (downloads a cert from the Cumulocity CA)
./scripts/bootstrap-device.sh tedge-ramem-2-0-1-3

# 3. Open a remote-access session and sample memory
./scripts/remote-access.sh tedge-ramem-2-0-1-3 15 results/manual.json

# 4. Poke around
docker compose exec device sh
#   . /data/tedge/env
#   tedgectl status tedge-mapper-c8y
#   ssh tedge@ssh-server            # verify plain connectivity to the target
```

## Interpreting the output

`measure.sh` reports peak (high-water) memory of each tedge component. The key line
of the comparison is **"RA plugin peak (1 proc)"** — the peak `VmHWM` of the single
largest `c8y-remote-access-plugin` process. That is the memory attributable to
running the remote-access plugin, and the figure the claim is about.

Comparing `VARIANT=` (upx) against `VARIANT=-noupx` for the *same* version isolates
how much of the difference is upx decompression versus the binary itself.

## Notes / caveats

- The device-side plugin only spawns once an operator actually connects through the
  tunnel, so `remote-access.sh` holds a TCP connection open for the whole sample
  window.
- `VmHWM` is a monotonic high-water mark, so coarse sampling still captures the peak;
  the current-`RSS` figures are more sample-timing sensitive.
- Each run uses a distinct external id (`tedge-ramem-<version>`) so the two versions
  don't share a device/certificate.
