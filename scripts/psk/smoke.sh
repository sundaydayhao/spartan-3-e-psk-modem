#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
first="${1:-0}"
last="${2:-27}"
variant="${3:-nominal}"
mkdir -p "build/smoke-$first-$variant"
cd "build/smoke-$first-$variant"
define=PSK_NOMINAL
if [[ "$variant" == stress ]]; then define=STRESS; fi
fuse -nodebug -d "$define" -generic_top "FIRST_MODE=$first" -generic_top "LAST_MODE=$last" -i ../../rtl/psk -prj ../../scripts/psk/sim.prj -o tb_receiver.exe tb_receiver > fuse.log 2>&1 || { cat fuse.log; exit 1; }
./tb_receiver.exe -tclbatch ../../scripts/sim.tcl -log simulation.log
grep -q 'PASS RTL waveform run completed' simulation.log
! grep -Eq 'FAIL|ERROR:|FATAL' simulation.log
python - <<'PY'
import glob
p='HELLO FPGA 123 TEST '
for file in glob.glob('*.txt'):
    s=open(file).read()
    i=s.find(p)
    assert i>=0,(file,repr(s[:200]))
    s=s[i:]
    assert len(s)>=2*len(p),(file,'Too little decoded text')
    assert s==(p*(len(s)//len(p)+1))[:len(s)],(file,repr(s[:300]))
    print('PASS %s: %d contiguous characters' % (file,len(s)))
PY
