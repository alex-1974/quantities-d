#!/usr/bin/env python3
"""Independent Fraction oracle for the closed identity API and all tuple shift cases."""
from pathlib import Path
import importlib.util
import random
import subprocess
import sys
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("api_reference",root/"r15-mixed-api/oracle.py")
reference=importlib.util.module_from_spec(spec);spec.loader.exec_module(reference)

def main():
    exe=sys.argv[1]
    traits=tuple(map(int,subprocess.check_output([exe,"--traits"],text=True).split()))
    p,mi,ma=traits
    real_ok=traits in ((64,-16381,16384),(53,-1021,1024))
    sources=[]
    for prefix,eb,pb in [("F",8,23),("D",11,52)]:
        # Every encoded exponent, signed, with zero, endpoint and half-bit tails.
        for ef in range(1<<eb):
            for tail in [0,1,(1<<pb)-1,1<<(pb-1)]:
                for neg in [0,1]: sources.append((prefix,[(neg<<(eb+pb))|(ef<<pb)|tail]))
    if real_ok:
        for sig in [0,1,3,(1<<(p-1))-1,1<<(p-1),(1<<p)-1]:
            for e in [mi-p,ma-p,-65,-64,-63,-2,-1,0,1,62,63,64]:
                for neg in [0,1]:sources.append(("R",[sig,e,neg]))
        if p==64:
            for sig,e in [((1<<63)-1,0),((1<<64)-1,-1),((1<<63)+1,0),((1<<64)-3,-1)]:
                for neg in [0,1]:sources.append(("R",[sig,e,neg]))
        sources.extend((x,[]) for x in "NPM")
    rng=random.Random(0x150019)
    for i in range(12000):
        prefix=rng.choice("FD"+("R" if real_ok else ""))
        raw=[rng.getrandbits(32 if prefix=="F" else 64)] if prefix!="R" else [rng.randrange(1,1<<p),rng.choice([-65,-64,-63,-2,-1,0,1,rng.randrange(mi-p,ma-p+1)]),rng.randrange(2)]
        sources.append((prefix,raw))
    cases=[];wanted=[]
    intents=[("C",0),("E",0),*(("R",m) for m in range(4))]
    for prefix,raw in sources:
        for intent,mode in intents:
            cases.append(" ".join(map(str,[prefix,intent,mode,0,*raw])))
            wanted.append(reference.expected((prefix,intent,mode,0,raw)))
    api_count=len(cases)
    tuples=[(sig,e,neg) for sig in [0,1,2,3,(1<<63)-1,1<<63,(1<<63)+1,(1<<64)-1]
            for e in [-16445,-1074,-149,-65,-64,-63,-62,-2,-1,0,1,62,63,64,16383] for neg in [0,1]]
    tuples += [(rng.getrandbits(64),rng.choice([-65,-64,-63,-1,0,1,rng.randrange(-200,200)]),rng.randrange(2)) for i in range(5000)]
    for sig,e,neg in tuples:
        for intent,mode in [("C",0),*(("R",m) for m in range(4))]:
            cases.append(f"T {intent} {mode} 0 {sig} {e} {neg}")
            wanted.append(reference.reference.expected(("R",intent,mode,[sig,e,neg],(1,1,1,1))))
    actual=subprocess.run([exe],input="\n".join(cases)+"\n",stdout=subprocess.PIPE,text=True,check=True).stdout.splitlines()
    assert len(actual)==len(wanted),(len(actual),len(wanted))
    bad=[(cases[i],a,b) for i,(a,b) in enumerate(zip(actual,wanted)) if a!=b]
    if bad:
        for item in bad[:12]:print("MISMATCH",item)
        raise SystemExit(1)
    print(f"R15 Probe 19 PASS: {api_count} API pairs / {2*api_count} directional comparisons, {len(cases)-api_count} tuple comparisons; real traits {traits}")
if __name__=="__main__":main()
