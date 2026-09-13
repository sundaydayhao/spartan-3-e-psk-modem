#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
cd "build/${3:-fec-$1}"
fuse -nodebug -generic_top "MODE=$1" -generic_top "COUNT=${2:-3000}" -generic_top "SKIP=${4:-17}" -i ../../rtl/psk -prj ../../scripts/psk/fec.prj -o tb_fec.exe tb_fec > fuse.log 2>&1 || { cat fuse.log;exit 1; }
./tb_fec.exe -tclbatch ../../scripts/sim.tcl -log simulation.log
grep -q 'PASS FEC symbol run' simulation.log
! grep -Eq 'FAIL|ERROR:|FATAL' simulation.log
python - <<'PY'
p='HELLO FPGA 123 TEST '
s=open('decoded.txt').read()
i=s.find(p)
assert i>=0,repr(s[:300])
s=s[i:]
assert len(s)>=2*len(p),'Too few complete payloads'
assert s==(p*(len(s)//len(p)+1))[:len(s)],repr(s[:300])
print('PASS contiguous FEC text: %d characters' % len(s))
PY
