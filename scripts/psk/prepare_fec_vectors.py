"""Capture encoded symbols from HPM C and inject deterministic channel errors."""
import subprocess,os,json,hashlib
from reference import ROOT,HPM
from modes import MODES
env=dict(os.environ)
env['PATH']=r'C:\cygwin64\bin;'+env['PATH']
sources=[ROOT/'scripts/psk/hpm_symbol_vectors.c']+[HPM/f'app/modem/{s}.c' for s in ('psk_tx','psk_codec','psk_modes')]
exe=ROOT/'build/reference-tools/hpm_symbol_vectors.exe'
subprocess.run([r'C:\cygwin64\bin\gcc.exe','-std=c11','-O2',
    '-I',str(HPM/'app/modem'),'-I',str(HPM/'third_party/psk_rtty/include'),
    *map(str,sources),'-lm','-o',str(exe)],check=True,env=env)
for index in [15,22,23,24,25,26]:
    p=ROOT/f'build/fec-{index}';p.mkdir(exist_ok=True)
    subprocess.run([str(exe),MODES[index][0],str(p/'symbols.hex'),'3000'],check=True,env=env)
    if index==22:
        mid=ROOT/'build/fec-midstream-22';mid.mkdir(exist_ok=True)
        (mid/'symbols.hex').write_bytes((p/'symbols.hex').read_bytes())
    if index in (22,24,26):
        symbols=[int(s,16) for s in (p/'symbols.hex').read_text().split()]
        positions=list(range(1000,len(symbols),401))
        for pos in positions:symbols[pos]^=1
        out=ROOT/f'build/fec-error-{index}';out.mkdir(exist_ok=True)
        content=''.join(f'{s:x}\n' for s in symbols)
        (out/'symbols.hex').write_text(content,newline='\n')
        (out/'manifest.json').write_text(json.dumps(dict(mode=MODES[index][0],count=3000,
            skip_symbols=17,flipped_lsb_at_symbols=positions,
            symbols_sha256=hashlib.sha256(content.encode()).hexdigest()),indent=2))
print('Prepared actual HPM symbols and five isolated errors per tested mode')
