#!/usr/bin/env bash
cd /home/ise/fpga-project || exit 1
name="$1"
shift
"$@"
rc=$?
printf '%s\n' "$rc" > "build/$name.exit"
exit "$rc"
