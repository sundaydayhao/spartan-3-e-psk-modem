#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/psk build/psk-board
cd build/psk-board
fuse -nodebug -i ../../rtl/psk -prj ../../scripts/psk/rotary.prj -o tb_rotary.exe tb_rotary > rotary-fuse.log 2>&1 || { cat rotary-fuse.log; exit 1; }
./tb_rotary.exe -tclbatch ../../scripts/sim.tcl -log rotary-simulation.log
grep -q 'PASS rotary bounce' rotary-simulation.log
! grep -q 'FAIL' rotary-simulation.log
fuse -nodebug -i ../../rtl/psk -prj ../../scripts/psk/board.prj -o tb_board.exe tb_board > board-fuse.log 2>&1 || { cat board-fuse.log; exit 1; }
./tb_board.exe -tclbatch ../../scripts/sim.tcl -log board-simulation.log
grep -q 'PASS ADC gain/framing/rate' board-simulation.log
! grep -q 'FAIL' board-simulation.log
cp rotary-simulation.log board-simulation.log ../psk/
