#!/usr/bin/env bash
set -euo pipefail
cd /home/ise/fpga-project
name="$1"
case "$name" in *[!a-zA-Z0-9_-]*) exit 2;; esac
if [[ -e "build/$name.pid" ]]; then echo 'Use a fresh job name';exit 3;fi
nohup bash scripts/psk/job_worker.sh "$@" > "build/$name.log" 2>&1 < /dev/null &
pid=$!
printf '%s\n' "$pid" > "build/$name.pid"
echo "Started $name PID $pid"
