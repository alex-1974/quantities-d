"""Independent represented-source checks, using pinned Fraction quantizers."""
from fractions import Fraction
from pathlib import Path
import random
import subprocess
import sys
sys.path.insert(0,str(Path(sys.argv[2])/'r15-exact-unit-rescale'))
from oracle import f32_fraction,f64_fraction,target_float,target_double
exe=sys.argv[1]
p,mi,ma=map(int,subprocess.check_output([exe,'--traits'],text=True).split())
assert (p,mi,ma) in ((64,-16381,16384),(53,-1021,1024))
rng=random.Random(0x150101)
limit=(1<<63)-1
ratios=[(1,1,1,1),(2,3,1,1),(-3,2,1,1),(381,1250,1200,3937),
        (limit,limit-18,limit-20,limit-6),(-(1<<63),limit,1,1),
        (1,limit,limit,1),(limit,1,1,limit)]
inputs=[('L',[n]) for n in [0,1,-1,limit,-(1<<63)]]
inputs += [('U',[n]) for n in [0,1,limit,1<<63,(1<<64)-1]]
for kind,words in [('F',[0,1,1<<31,0x7fffff,0x800000,0x3f000000,0x7f7fffff,0x7f800000,0x7fc00001,0x7f800001]),
                   ('D',[0,1,1<<63,0xfffffffffffff,0x10000000000000,0x3fe0000000000000,0x7fefffffffffffff,0x7ff0000000000000,0x7ff8000000000001,0x7ff0000000000001])]:
    inputs += [(kind,[n]) for n in words]
inputs += [('R',[s,e,neg]) for s,e in [(0,0),(1,mi-p),((1<<p)-1,ma-p),(3,-1),((1<<p)-1,0)] for neg in [0,1]]
inputs += [(kind,[]) for kind in 'NPM']
cases=[(target,kind,raw,ratio) for target in 'FD' for kind,raw in inputs for ratio in ratios]
for i in range(20000):
    kind=rng.choice('LUFDR')
    if kind=='L': raw=[rng.randrange(-(1<<63),1<<63)]
    elif kind=='U': raw=[rng.getrandbits(64)]
    elif kind=='F': raw=[rng.getrandbits(32)]
    elif kind=='D': raw=[rng.getrandbits(64)]
    else: raw=[rng.randrange(1,1<<p),rng.randrange(mi-1,ma-p+1),rng.randrange(2)]
    ratio=rng.choice(ratios) if i%2 else tuple(rng.randrange(1,1<<63) for _ in range(4))
    cases += [(target,kind,raw,ratio) for target in 'FD']
def expected(case):
    target,kind,raw,(fn,fd,tn,td)=case
    neg=False
    if kind in 'NPM': return 'nonFinite -'
    if kind in 'LU': value=Fraction(raw[0]); neg=raw[0]<0
    elif kind in 'FD':
        value=(f32_fraction if kind=='F' else f64_fraction)(raw[0])
        neg=bool(raw[0]>>(31 if kind=='F' else 63))
        if value is None: return 'nonFinite -'
    else:
        s,e,n=raw
        # Construct the actual native represented source, including subnormal
        # quantization. Random exponents stay normal; fixed subnormals are exact.
        value=Fraction(s)*(Fraction(1<<e) if e>=0 else Fraction(1,1<<-e))
        neg=bool(n)
        if neg: value=-value
    value*=Fraction(fn*td,fd*tn)
    decode=f32_fraction if target=='F' else f64_fraction
    bound=decode(0x7f7fffff if target=='F' else 0x7fefffffffffffff)
    if abs(value)>bound: return 'overflow -'
    bits,overflow=(target_float if target=='F' else target_double)(value)
    assert not overflow
    if not value: bits=int((neg!=(fn<0))!=(tn<0))<<(31 if target=='F' else 63)
    return f"{'exact' if decode(bits)==value else 'inexact'} {bits}"
lines=[' '.join(map(str,[t,k,*r,*ratio])) for t,k,r,ratio in cases]
result=subprocess.run([exe],input='\n'.join(lines)+'\n',text=True,capture_output=True,check=True)
observed=result.stdout.splitlines()
assert len(observed)==len(cases),(len(observed),len(cases))
for i,(case,actual) in enumerate(zip(cases,observed)):
    wanted=expected(case)
    assert actual==wanted,(i,case,wanted,actual)
print(f'represented sources -> float/double: {len(cases)} cases passed; real traits {(p,mi,ma)}')
