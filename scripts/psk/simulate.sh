#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/psk
cd build/psk
define=PSK_NOMINAL
if [[ "${1:-}" == '--stress' ]]; then define=STRESS; fi
fuse -nodebug -d "$define" -i ../../rtl/psk -prj ../../scripts/psk/sim.prj -o tb_receiver.exe tb_receiver > fuse.log 2>&1 || { cat fuse.log; exit 1; }
./tb_receiver.exe -tclbatch ../../scripts/sim.tcl -log simulation.log
grep -q 'PASS RTL waveform run completed' simulation.log
! grep -Eq 'FAIL|ERROR:|FATAL' simulation.log
result=nominal
if [[ "${1:-}" == '--stress' ]]; then result=stress; fi
mkdir -p "$result"
cp ./*PSK*.txt simulation.log "$result/"
