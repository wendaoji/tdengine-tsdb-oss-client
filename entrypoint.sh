#!/usr/bin/env bash
set -euo pipefail
TMPDIR=${TMPDIR:-/tmp}

trap 'kill -TERM $PID; wait $PID' TERM INT


"$@"
