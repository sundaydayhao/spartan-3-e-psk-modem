#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
cd build
fuse -prj ../scripts/sim.prj -o tb_led_demo.exe tb_led_demo
./tb_led_demo.exe -tclbatch ../scripts/sim.tcl -log simulation.log
grep -q '^PASS:' simulation.log
if grep -q '^FAIL' simulation.log; then exit 1; fi
