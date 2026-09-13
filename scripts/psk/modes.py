"""HPM text modes, excluding the deliberately omitted 2x8PSK1200F.

Family: 0=BPSK, 1=USB QPSK with K=5 FEC, 2=8PSK without FEC.
Rate code: baud = 31.25 * 2**rate, giving 16 samples per symbol after decimation.
"""
MODES = [
    ('BPSK31',0,0),('BPSK63',0,1),('BPSK125',0,2),('BPSK250',0,3),
    ('BPSK500',0,4),('BPSK1000',0,5),
    ('QPSK31',1,0),('QPSK63',1,1),('QPSK125',1,2),('QPSK250',1,3),('QPSK500',1,4),
    ('8PSK125',2,2),('8PSK250',2,3),('8PSK500',2,4),('8PSK1000',2,5),
    ('BPSK63F',0,1),
    ('12xPSK125',0,2),('6xPSK250',0,3),('2xPSK500',0,4),
    ('4xPSK500',0,4),('2xPSK800',0,6),('2xPSK1000',0,5),
    ('8PSK125F',2,2),('8PSK250F',2,3),('8PSK500F',2,4),
    ('8PSK1000F',2,5),('8PSK1200F',2,7),
]

def parameters(name):
    name,family,rate=next(m for m in MODES if m[0]==name)
    baud={6:800,7:16000/13}.get(rate,31.25*2**rate)
    carriers=int(name.split('x')[0]) if 'x' in name else 1
    k,p0,p1,depth,puncture=0,0,0,0,0
    if family==1: k,p0,p1=5,0x17,0x19
    if name=='BPSK63F': k,p0,p1=7,0x6d,0x4f
    if name in ('8PSK125F','8PSK250F'):
        k,p0,p1,depth=16,0o152711,0o126723,384 if rate==2 else 512
    if name=='8PSK500F': k,p0,p1,depth,puncture=13,0o16461,0o12767,640,1
    if name in ('8PSK1000F','8PSK1200F'): k,p0,p1,depth,puncture=7,0x6d,0x4f,512,1
    return dict(baud=baud,carriers=carriers,k=k,p0=p0,p1=p1,depth=depth,puncture=puncture,
                mfsk=int(family==2 or name=='BPSK63F'))

def frame_count(rate,name=''):
    # At least 6 seconds for fast modes: enough to cover the HPM preamble
    # (up to 1.024 s here), FEC latency and many complete text repetitions.
    return int((40 if name=='BPSK63F' else 12 if name=='8PSK125F' else
                8 if name.endswith('F') else max(6,20/(2**rate)))*16000)
