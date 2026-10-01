#!/usr/bin/env python3
from collections import Counter
from pathlib import Path
import importlib.util
import random
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("r15_reference",root/"r15-floating-source-integral/oracle.py")
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)
MAX, MIN = (1 << 63)-1, -(1 << 63)
# Unit, Spec.CanonicalUnit. This mirrors declared metadata, not kernel arithmetic.
pairs = [((1,1),(1,1)),((381,1250),(1,1)),((1200,3937),(1,1)),
         ((MAX,MAX-18),(MAX-20,MAX-6)),((1200,3937),(381,1250)),
         ((381,1250),(MIN,MAX))]

def expected(case):
    prefix,intent,mode,pair,raw = case
    unit,canonical = pairs[pair]
    outcomes = []
    for factors in [(*unit,*canonical),(*canonical,*unit)]:
        result = reference.expected((prefix,"C" if intent=="E" else intent,mode,raw,factors))
        if intent=="E":
            status,payload = result.split()
            result = f"value {payload}" if status=="exact" else f"failure {status}"
        outcomes.append(result)
    return " | ".join(outcomes)

def main():
    exe = sys.argv[1]
    traits = tuple(map(int,subprocess.check_output([exe,"--traits"],text=True).split()))
    real_ok = traits in ((64,-16381,16384),(53,-1021,1024))
    fixed = []
    for prefix,values in [
        ("F",[0,1,0x80000000,0x007fffff,0x00800000,0x3fc00000,
              0xbfc00000,0x5effffff,0x5f000000,0xdf000000,
              0x7f7fffff,0x7f800000,0xff800000,0x7fc00001]),
        ("D",[0,1,1 << 63,0x000fffffffffffff,0x0010000000000000,
              0x3ff8000000000000,0xbff8000000000000,0x43dfffffffffffff,
              0x43e0000000000000,0xc3e0000000000000,0x7fefffffffffffff,
              0x7ff0000000000000,0xfff0000000000000,0x7ff8000000000001])]:
        fixed.extend((prefix,[v]) for v in values)
    if real_ok:
        p,mi,ma = traits
        values = [(0,0),(1,mi-p),((1 << p)-1,ma-p),(1,63),(3,-1)]
        if p==64: values += [(MAX,0),((1 << 64)-1,-1)]
        fixed.extend(("R",[sig,e,neg]) for sig,e in values for neg in [0,1])
        fixed.extend((prefix,[]) for prefix in "NPM")
    cases = []
    for prefix,raw in fixed:
        for pair in range(len(pairs)):
            cases.extend((prefix,intent,mode,pair,raw)
                         for intent,mode in [("C",0),("E",0),*(('R',m) for m in range(4))])
    rng = random.Random(0x150014)
    for i in range(12000):
        prefix = rng.choice("FD"+("R" if real_ok else ""))
        if prefix=="F": raw = [rng.getrandbits(32)]
        elif prefix=="D": raw = [rng.getrandbits(64)]
        else:
            p,mi,ma = traits
            raw = [rng.randrange(1,1 << p),rng.choice([mi-p,ma-p,-1,0,rng.randrange(mi-p,ma-p+1)]),rng.randrange(2)]
        cases.append((prefix,rng.choice("CER"),rng.randrange(4),rng.randrange(len(pairs)),raw))
    wanted = [expected(v) for v in cases]
    payload = "".join(" ".join(map(str,[prefix,intent,mode,pair,*raw]))+"\n"
                      for prefix,intent,mode,pair,raw in cases)
    result = subprocess.run([exe],input=payload,text=True,stdout=subprocess.PIPE,check=True)
    actual = result.stdout.splitlines()
    assert len(actual)==len(wanted), (len(actual),len(wanted))
    bad = [(cases[i],a,b) for i,(a,b) in enumerate(zip(actual,wanted)) if a!=b]
    if bad:
        for v in bad[:12]: print("MISMATCH",v)
        raise SystemExit(1)
    counts = Counter(part.split()[0] for v in wanted for part in v.split(" | "))
    print(f"R15 Probe 14 PASS: {len(cases)} API pairs / {2*len(cases)} directional comparisons; {dict(counts)}; real traits {traits}")

if __name__=="__main__": main()
