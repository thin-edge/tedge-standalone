#!/usr/bin/env bash
# Shared helpers for the remote-access memory experiment.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "$HERE/.." && pwd)"
REPO_ROOT="$(cd "$EXP_DIR/../.." && pwd)"
RESULTS_DIR="$EXP_DIR/results"

# Load configuration: experiment-local .env first, then the repo .env as fallback
# (the repo .env already holds C8Y_BASEURL / C8Y_USER / C8Y_PASSWORD / C8Y_TENANT).
load_env() {
    set -a
    # shellcheck disable=SC1091
    [ -f "$REPO_ROOT/.env" ] && . "$REPO_ROOT/.env"
    # shellcheck disable=SC1091
    [ -f "$EXP_DIR/.env" ] && . "$EXP_DIR/.env"
    set +a

    # Map the repo's variable names onto what go-c8y-cli expects.
    export C8Y_HOST="${C8Y_HOST:-${C8Y_BASEURL:-}}"
    export C8Y_USER="${C8Y_USER:-}"
    export C8Y_PASSWORD="${C8Y_PASSWORD:-}"
    export C8Y_TENANT="${C8Y_TENANT:-}"
    # Don't accidentally pick up an unrelated go-c8y-cli session.
    export C8Y_SESSION="${C8Y_SESSION:-}"

    : "${C8Y_HOST:?C8Y_HOST/C8Y_BASEURL must be set (Cumulocity URL)}"
    : "${C8Y_USER:?C8Y_USER must be set}"
    : "${C8Y_PASSWORD:?C8Y_PASSWORD must be set}"

    # URL without scheme, for the device-side bootstrap.sh --c8y-url argument
    export C8Y_URL_NOSCHEME="${C8Y_HOST#http://}"
    export C8Y_URL_NOSCHEME="${C8Y_URL_NOSCHEME#https://}"
    export C8Y_URL_NOSCHEME="${C8Y_URL_NOSCHEME%/}"
}

# A filesystem-safe slug for a version string, e.g. 2.0.1-3 -> 2-0-1-3
slug() { echo "$1" | tr './+' '-'; }

dc() { docker compose -f "$EXP_DIR/docker-compose.yml" "$@"; }

log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }
