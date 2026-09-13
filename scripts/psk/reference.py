"""Independent algorithm model and ROM/vector generator; RTL tests are separate."""
from pathlib import Path
import re, wave, subprocess, os, math
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
HPM = Path(r'C:\projects\hpm6750-psk-modem')
TABLE = [int(x, 16) for x in re.findall(r'0x[0-9A-F]+', (HPM/'third_party/psk_rtty/include/PSKTables.h').read_text())]
DECODE = {v: chr(i) for i, v in enumerate(TABLE[:128])}
MFSK_TABLE = [int(x,16) for x in re.findall(r'0x[0-9A-F]+',
    (HPM/'app/modem/psk_codec.c').read_text().split('s_mfsk_varicode_encode[256] = {')[1].split('};')[0])]
MFSK_DECODE = {v:chr(i) for i,v in enumerate(MFSK_TABLE[:128]) if i}
PAYLOAD = 'HELLO FPGA 123 TEST '

def vectors():
    env = dict(os.environ)
    env['PATH'] = r'C:\cygwin64\bin;' + env['PATH']
    for mode in ['BPSK31','QPSK31','BPSK63','QPSK63','BPSK125','QPSK125','BPSK250','QPSK250']:
        subprocess.run([str(ROOT/'build/reference-tools/host_tx_wav.exe'), mode,
            str(ROOT/f'build/psk-vectors/{mode}.wav'), '--text',PAYLOAD, '--loop',
            '--sample-rate','16000','--wav-rate','16000','--tone-hz','2000',
            '--channels','1','--max-seconds','20'],env=env,check=True)

def vit(symbols):
    metric = [0]*16
    paths = [0]*16
    out=[]
    for k, sym in enumerate(symbols):
        nm=[]; npth=[]
        for s in range(16):
            a=s>>1; b=a+8
            code=((s&0x17).bit_count()&1) | (((s&0x19).bit_count()&1)<<1)
            ma=metric[a]+(code^sym).bit_count()
            mb=metric[b]+((code^3)^sym).bit_count()
            p=a if ma<=mb else b
            nm.append(min(ma,mb))
            npth.append(((paths[p]<<1)|(s&1)) & ((1<<48)-1))
        best=min(range(16),key=lambda s:nm[s]); low=nm[best]
        metric=[m-low for m in nm]; paths=npth
        if k>=47: out.append((paths[best]>>47)&1)
    return out

def text_bits(bits):
    acc=0; prev=0; out=''
    for bit in bits:
        if not bit and not prev:
            out += DECODE.get(acc>>1,'')
            acc=0
        else: acc=((acc<<1)|bit)&0xfff
        prev=bit
    return out

def text_mfsk(bits):
    acc=1;out=''
    for bit in bits:
        acc=((acc<<1)|bit)&0xfff
        if (acc&7)==1:
            out+=MFSK_DECODE.get(acc>>1,'');acc=1
    return out

def model(path, rate=0, qpsk=False, offset=0, psk8=False):
    with wave.open(str(path),'rb') as f:
        a=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float64)/4
    a=a[offset:]
    n=np.arange(len(a)); z=a*np.exp(2j*np.pi*2000*n/16000)
    dec=32>>rate; z=z[:len(z)//dec*dec].reshape(-1,dec).mean(axis=1)
    h=np.sinc((np.arange(33)-16)*2/16)*np.hamming(33); h/=sum(h)
    z=np.convolve(z,h)[:len(z)]
    energy=np.zeros(16); phase=0.; prev=0j; syms=[]
    for sample in z:
        idx=int(phase)
        energy[idx] += (abs(sample)**2-energy[idx])/4
        amp=sum(energy)
        err=(sum(energy[:8])-sum(energy[8:]))/amp if amp else 0
        phase+=1-err/5
        if phase>=16:
            phase-=16
            dp=sample*prev.conjugate(); prev=sample
            if psk8:
                p=int(np.floor(np.angle(dp)/(np.pi/4)+.5))%8
                syms.append(p^4)
            else:
                p=int(np.floor(np.angle(dp)/(np.pi/2)+.5))%4
                syms.append([2,1,0,3][p] if qpsk else int(dp.real>=0))
    if psk8: return text_mfsk([(s>>b)&1 for s in syms for b in range(3)])
    bits=vit(syms) if qpsk else syms
    return text_bits(bits)

if __name__=='__main__':
    import sys
    if '--generate' in sys.argv: vectors()
    from modes import MODES
    for name,family,rate in MODES:
            p=ROOT/f'build/psk-vectors/{name}.wav'
            s=model(p,rate,family==1,137,family==2)
            print(p.stem,repr(s[:150]),s.count(PAYLOAD))
            assert PAYLOAD in s, p
