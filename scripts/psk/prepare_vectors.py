"""Build reproducible PCM fixtures using the real HPM transmitter executable."""
from reference import ROOT, HPM, PAYLOAD, TABLE
from modes import MODES,frame_count
import subprocess, os, wave, json, hashlib
import numpy as np
env=dict(os.environ)
env['PATH']=r'C:\cygwin64\bin;'+env['PATH']
rng=np.random.default_rng(20260912)
for stress in [False,True]:
    out=ROOT/('build/psk-stress' if stress else 'build/psk-vectors')
    out.mkdir(parents=True,exist_ok=True)
    for name,family,rate in MODES:
            p=out/f'{name}.wav'
            subprocess.run([str(ROOT/'build/reference-tools/host_tx_wav.exe'),name,str(p),
                '--text',PAYLOAD,'--loop','--sample-rate','16000','--wav-rate','16000',
                '--tone-hz','2001' if stress else '2000','--channels','1','--max-seconds',str(frame_count(rate,name)//16000)],
                env=env,check=True,stdout=subprocess.DEVNULL)
            with wave.open(str(p),'rb') as w:
                # The C tool writes whole 512-sample chunks, possibly extending
                # beyond its duration guard. Use an exact-length RTL fixture.
                data=np.frombuffer(w.readframes(frame_count(rate,name)),dtype='<i2').astype(float)/4
                assert len(data)==frame_count(rate,name),(name,'short source WAV')
            if stress:
                # Independent sample-clock error (+100 ppm), attenuation,
                # input polarity inversion (board gain=-1), DC offset, noise.
                data=np.interp(np.arange(len(data))*1.0001,np.arange(len(data)),data)
                data=-data*.3+300+rng.normal(0,20,len(data))
            data=np.clip(np.floor(data),-8192,8191).astype(int)
            p.with_suffix('.hex').write_text(''.join(f'{int(v)&16383:04x}\n' for v in data))
    manifest={'payload':PAYLOAD,'modes':MODES,'sample_rate':16000,
        'frames':{name:frame_count(rate,name) for name,_,rate in MODES},
        'carrier_hz':2001 if stress else 2000,'stress':stress,
        'stress_conditions':'gain -0.3, DC +300 ADC counts, Gaussian noise sigma 20, sample clock +100 ppm' if stress else None,
        'transmitter_sources':{str(p.relative_to(HPM)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [HPM/'app/modem/psk_tx.c',HPM/'app/modem/psk_codec.c',HPM/'app/modem/psk_modes.c',
                HPM/'third_party/psk_rtty/include/PSKTables.h']}}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print('Prepared',out)
