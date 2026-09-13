"""Diagnostic model fed by symbols captured from the actual HPM C transmitter.
The production implementation is Verilog and is tested separately by ISim.
"""
from modes import MODES,parameters
from reference import text_mfsk,ROOT,PAYLOAD
import sys
def pairs(index,skip=17,symbols=None):
    name=MODES[index][0];p=parameters(name);d=p['depth']
    if symbols is None:
        symbols=[int(x,16) for x in (ROOT/f'build/fec-{index}/symbols.hex').read_text().split()]
    symbols=symbols[skip:]
    if p['puncture']:
        streams=[[(s&1,(s>>1)&1,3) for s in []]]
        stream=[]
        for s in symbols:stream.extend([(s&1,(s>>1)&1,3),((s>>2)&1,0,1)])
        streams=[stream]
    else:
        bits=[(s>>b)&1 for s in symbols for b in range(3 if MODES[index][1]==2 else 1)]
        streams=[[(bits[i],bits[i+1],3) for i in range(phase,len(bits)-1,2)] for phase in range(2)]
    for stream in streams:
        out=[]
        for t in range(d,len(stream)):
            a=stream[t][0];b=stream[t-d][1];known=(stream[t][2]&1)|(stream[t-d][2]&2)
            out.append((a|(b<<1),known))
        yield out
def decode(index,stream):
    p=parameters(MODES[index][0]);k=p['k'];mask=(1<<(k-1))-1
    paths=[(0,i,0) for i in range(64)] if k==7 else [(0,0,0)]
    obs0=obs1=seed=0;bits=[];cost=0
    for t,(pair,known) in enumerate(stream):
        if k>7:paths=paths[:63]+[(1,seed,0)]
        obs0=((obs0<<1)|(pair&1))&0xffffffff;obs1=((obs1<<1)|(pair>>1))&0xffffffff
        a,b=(0x74c4,0x5073) if k==16 else (0x6b5ca,0x50005) if known&2 else (0xd6b79f,0xa008a2)
        bit=((obs0&a).bit_count()^(obs1&b).bit_count())&1
        seed=((seed<<1)|bit)&mask
        choices={}
        for metric,state,hist in paths:
            for bit in (0,1):
                e=(state<<1)|bit
                code=((e&p['p0']).bit_count()&1)|(((e&p['p1']).bit_count()&1)<<1)
                m=metric+((code^pair)&known).bit_count();s=e&mask
                if s not in choices or m<choices[s][0]:
                    choices[s]=(m,s,((hist<<1)|bit)&((1<<192)-1))
        paths=sorted(choices.values(),key=lambda x:x[0])[:64]
        low=paths[0][0];cost+=low
        paths=[(m-low,s,h) for m,s,h in paths]
        if t>=191:bits.append((paths[0][2]>>191)&1)
    return text_mfsk(bits),cost
if __name__=='__main__':
    for index in map(int,sys.argv[1:] or [15,22,24,26]):
        for branch,stream in enumerate(pairs(index)):
            text,cost=decode(index,stream)
            print(MODES[index][0],branch,cost,text.count(PAYLOAD),repr(text[:180]),flush=True)

