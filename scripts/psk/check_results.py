"""Check actual RTL output for complete, contiguous HPM payload repetitions."""
from reference import ROOT, PAYLOAD
from modes import MODES
import sys
directory=ROOT/'build/psk'
if len(sys.argv)>1: directory=ROOT/sys.argv[1]
for name,_,_ in MODES:
        s=(directory/f'{name}.txt').read_text()
        start=s.find(PAYLOAD)
        assert start>=0,(name,repr(s))
        decoded=s[start:]
        expected=(PAYLOAD*((len(decoded)//len(PAYLOAD))+1))[:len(decoded)]
        assert decoded==expected,(name,repr(s))
        assert len(decoded)>=len(PAYLOAD)*2,(name,'too little decoded data')
        print(f'PASS {name}: {len(decoded)} contiguous characters, {decoded.count(PAYLOAD)} complete payloads')
