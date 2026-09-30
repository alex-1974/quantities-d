#!/usr/bin/env python3
from fractions import Fraction
from pathlib import Path
import random
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"r15-exact-unit-rescale"))
from oracle import target_float,target_double,f32_fraction,f64_fraction

def expected(case):
    target,sig,e,neg,fn,fd,tn,td=case
    raw=Fraction(sig*fn*td,fd*tn)
    nb=abs(raw.numerator).bit_length()
    db=raw.denominator.bit_length()
    x=raw*(Fraction(1<<e) if e>=0 else Fraction(1,1<<-e))
    if neg:x=-x
    decode=f32_fraction if target=="F" else f64_fraction
    bound=decode(0x7f7fffff if target=="F" else 0x7fefffffffffffff)
    if abs(x)>bound:
        return f"overflow - {nb} {db}"
    bits,overflow=target_float(x) if target=="F" else target_double(x)
    assert not overflow
    if x==0:
        sign=(bool(neg)!=(fn<0))!=(tn<0)
        bits=int(sign)<<(31 if target=="F" else 63)
    status="exact" if decode(bits)==x else "inexact"
    return f"{status} {bits} {nb} {db}"

def main():
    rng=random.Random(0x150011)
    cases=[]
    limit=(1<<63)-1
    s=(1<<64)-1
    witness=[9223372036854775807,9223372036854775801,
             9223372036854775789,9223372036854775787]
    a,b,c,d=witness
    fixed=[
        (s,0,0,a,c,d,b),
        (s,0,1,a,c,d,b),
        (s,0,0,a,c,a,c), # Complete cancellation of identical Unit scales.
        (0,0,0,a,c,d,b),(0,0,1,-a,c,d,b),
        (1,0,0,(1<<60)+(1<<36)+1,1<<60,1,1),
        ((1<<53)-1,971,0,(1<<62)+1,1<<62,1,1),
        ((1<<53)-1,971,1,(1<<62)+1,1<<62,1,1),
        ((1<<24)-1,104,0,(1<<62)+1,1<<62,1,1),
        (1,-149,0,3,2,1,1),(1,-1074,1,3,2,1,1),
        (s,0,0,-(1<<63),limit,limit,limit-2),
        (s,0,0,limit,limit-2,-(1<<63),limit),
        (1,0,0,1,limit,limit,1),
        (1,0,0,limit,1,1,limit),
        (1,-16445,0,a,c,d,b),(s,16320,0,a,c,d,b)]
    for target in "FD":
        cases.extend((target,*v) for v in fixed)
    for i in range(20000):
        sig=rng.choice([0,1,s,rng.getrandbits(64)])
        e=rng.choice([0,971,104,-149,-1074,-16445,16320,rng.randrange(-16445,16321)])
        neg=rng.randrange(2)
        factors=[rng.randrange(1,1<<63) for _ in range(4)]
        if i%3==0: factors=[a,c,d,b]
        if i%7==0: factors[2:]=factors[:2]
        if i%11==0: factors[0]=-(1<<63)
        if i%13==0: factors[2]=-factors[2]
        cases.append((rng.choice("FD"),sig,e,neg,*factors))
    wanted=[expected(v) for v in cases]
    assert wanted[0].split()[-2:]==["190","126"],wanted[0]
    payload="".join(" ".join(map(str,v))+"\n" for v in cases)
    p=subprocess.run([sys.argv[1]],input=payload,text=True,
                     stdout=subprocess.PIPE,check=True)
    actual=p.stdout.splitlines()
    assert len(actual)==len(wanted),(len(actual),len(wanted))
    bad=[(cases[i],x,y) for i,(x,y) in enumerate(zip(actual,wanted)) if x!=y]
    if bad:
        for v in bad[:12]:print("MISMATCH",v)
        raise SystemExit(1)
    print(f"R15 Probe 11 PASS: {len(cases)} composed-scale comparisons; reduced witness 190/126 bits")

if __name__=="__main__":main()
