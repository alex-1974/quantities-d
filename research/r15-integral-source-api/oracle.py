#!/usr/bin/env python3
"""Exact Fraction oracle for long/ulong to long: composed ratios and range before rounding."""
from fractions import Fraction
from pathlib import Path
import importlib.util,random,subprocess,sys
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("prior",root/"r15-mixed-api/oracle.py")
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
MIN,MAX=-(1<<63),(1<<63)-1
A=1<<62
pairs=prior.pairs+[((1,2),(1,1)),((1,4),(1,1)),((MIN,1),(1,1)),((1,MAX),(1,1)),
                   ((A-1,A),(A,A+1)),((MIN,1),(1,MAX))]

def expected(prefix,value,pair,intent,mode):
    unit,canonical=pairs[pair];out=[]
    for f,t in [(unit,canonical),(canonical,unit)]:
        x=Fraction(value)*Fraction(*f)/Fraction(*t)
        if x<MIN or x>MAX: status,payload="overflow","-"
        elif x.denominator==1: status,payload="exact",str(x.numerator)
        elif intent!="R": status,payload="inexact","-"
        else:
            if mode==0: rounded=int(x)
            elif mode==1: rounded=x.numerator//x.denominator
            elif mode==2: rounded=-((-x.numerator)//x.denominator)
            else:
                rounded=(2*abs(x.numerator)+x.denominator)//(2*x.denominator)
                if x<0:rounded=-rounded
            assert MIN<=rounded<=MAX
            status,payload="inexact",str(rounded)
        out.append((f"value {payload}" if status=="exact" else f"failure {status}") if intent=="E" else f"{status} {payload}")
    return " | ".join(out)

def main():
    exe=sys.argv[1];rng=random.Random(0x150020);cases=[]
    fixed=[]
    for prefix in "LU":
        domain=([MIN,MIN+1,-MAX,-3,-2,-1,0,1,2,3,MAX-1,MAX] if prefix=="L" else [0,1,2,3,MAX-1,MAX,MAX+1,MAX+2,(1<<64)-2,(1<<64)-1])
        for b in range(64):
            for v in [(1<<b)-1,1<<b,(1<<b)+1]:
                if prefix=="L":domain.extend([v,-v])
                else:domain.append(v)
        lo,hi=(MIN,MAX) if prefix=="L" else (0,(1<<64)-1)
        fixed.extend((prefix,v) for v in sorted(set(domain)) if lo<=v<=hi)
    for prefix,v in fixed:
        for pair in range(len(pairs)):
            for intent,mode in [("C",0),("E",0),*(("R",m) for m in range(4))]:cases.append((prefix,v,pair,intent,mode))
    for i in range(20000):
        prefix=rng.choice("LU");value=rng.randrange(MIN,MAX+1) if prefix=="L" else rng.getrandbits(64)
        cases.append((prefix,value,rng.randrange(len(pairs)),rng.choice("CER"),rng.randrange(4)))
    wanted=[expected(*case) for case in cases]
    payload="".join(f"{prefix} {intent} {mode} {pair} {value}\n" for prefix,value,pair,intent,mode in cases)
    actual=subprocess.run([exe],input=payload,stdout=subprocess.PIPE,text=True,check=True).stdout.splitlines()
    assert len(actual)==len(wanted),(len(actual),len(wanted))
    bad=[(cases[i],a,b) for i,(a,b) in enumerate(zip(actual,wanted)) if a!=b]
    if bad:
        for item in bad[:12]:print("MISMATCH",item)
        raise SystemExit(1)
    print(f"R15 Probe 20 PASS: {len(cases)} integral API pairs / {2*len(cases)} directional comparisons, zero mismatches; CTFE and runtime consumer pass")
if __name__=="__main__":main()
