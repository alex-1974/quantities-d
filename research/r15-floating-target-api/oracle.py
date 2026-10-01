#!/usr/bin/env python3
from collections import Counter
from fractions import Fraction
from pathlib import Path
import random
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"r15-exact-unit-rescale"))
from oracle import f32_fraction,f64_fraction,target_float,target_double
MAX,MIN = (1 << 63)-1,-(1 << 63)
pairs = [((1,1),(1,1)),((381,1250),(1,1)),((1200,3937),(1,1)),
         ((MAX,MAX-18),(MAX-20,MAX-6)),((1200,3937),(381,1250)),
         ((381,1250),(MIN,MAX)),(((1 << 60)+(1 << 36)+1,1 << 60),(1,1)),
         (((1 << 62)+1,1 << 62),(1,1))]

def expected(case):
    prefix,target,intent,pair,raw = case
    if prefix in "NPM": source = None; negative = prefix=="M"
    elif prefix in "LU": source = Fraction(raw[0]); negative = source < 0
    elif prefix in "FD":
        source = f32_fraction(raw[0]) if prefix=="F" else f64_fraction(raw[0])
        negative = bool(raw[0] >> (31 if prefix=="F" else 63))
    else:
        sig,e,neg = raw
        source = Fraction(sig << e) if e>=0 else Fraction(sig,1 << -e)
        if neg: source = -source
        negative = bool(neg)
    unit,canonical = pairs[pair]
    outputs = []
    decode = f32_fraction if target=="F" else f64_fraction
    bound = decode(0x7f7fffff if target=="F" else 0x7fefffffffffffff)
    for frm,to in [(unit,canonical),(canonical,unit)]:
        bits = None
        if source is None: status = "nonFinite"
        else:
            ratio = Fraction(frm[0]*to[1],frm[1]*to[0])
            x = source*ratio
            if abs(x)>bound: status = "overflow"
            else:
                bits,overflow = target_float(x) if target=="F" else target_double(x)
                assert not overflow
                if x==0: bits = int(negative != (ratio<0)) << (31 if target=="F" else 63)
                status = "exact" if decode(bits)==x else "inexact"
        if intent=="E":
            outputs.append(f"value {bits}" if status=="exact" else f"failure {status}")
        else: outputs.append(f"{status} {bits}" if bits is not None else f"{status} -")
    return " | ".join(outputs)

def main():
    exe = sys.argv[1]
    traits = tuple(map(int,subprocess.check_output([exe,"--traits"],text=True).split()))
    real_ok = traits in ((64,-16381,16384),(53,-1021,1024))
    fixed = []
    for prefix,values in [
        ("L",[MIN,MAX,0,1,-1,(1 << 24)+1,(1 << 53)+1]),
        ("U",[0,1,(1 << 64)-1,1 << 63,(1 << 24)+1,(1 << 53)+1]),
        ("F",[0,1,0x80000000,0x007fffff,0x00800000,0x3f800000,
              0x3f800001,0x3fc00000,0xbf800000,0x7f7fffff,0xff7fffff,
              0x7f800000,0xff800000,0x7fc00001,0x7f800001]),
        ("D",[0,1,1 << 63,0x000fffffffffffff,0x0010000000000000,
              0x3ff0000000000000,0x3ff0000000000001,0x3ff8000000000000,
              0xbff0000000000000,0x7fefffffffffffff,0xffefffffffffffff,
              0x7ff0000000000000,0xfff0000000000000,0x7ff8000000000001,
              0x7ff0000000000001])]:
        fixed.extend((prefix,[v]) for v in values)
    if real_ok:
        p,mi,ma = traits
        values = [(0,0),(1,mi-p),(2,mi-p),(1 << (p-1),mi-p),
                  ((1 << p)-1,ma-p),(1,0),(3,-1),
                  (1,-149),(1,-150),(1,-1074),(1,-1075)]
        fixed.extend(("R",[sig,e,neg]) for sig,e in values for neg in [0,1])
        fixed.extend((prefix,[]) for prefix in "NPM")
    cases = []
    for prefix,raw in fixed:
        for target in "FD":
            for intent in "CE":
                cases.extend((prefix,target,intent,pair,raw) for pair in range(len(pairs)))
    rng = random.Random(0x150015)
    for i in range(20000):
        prefix = rng.choice("LUFD"+("R" if real_ok else ""))
        if prefix=="L": raw = [rng.randrange(MIN,MAX+1)]
        elif prefix=="U": raw = [rng.getrandbits(64)]
        elif prefix=="F": raw = [rng.getrandbits(32)]
        elif prefix=="D": raw = [rng.getrandbits(64)]
        else:
            p,mi,ma = traits
            raw = [rng.randrange(1,1 << p),rng.choice([mi-p,ma-p,-149,-1074,0,rng.randrange(mi-p,ma-p+1)]),rng.randrange(2)]
        cases.append((prefix,rng.choice("FD"),rng.choice("CE"),rng.randrange(len(pairs)),raw))
    wanted = [expected(v) for v in cases]
    # Explicit oracle control of the direct-rounding witness.
    assert expected(("D","F","C",6,[0x3ff0000000000000])).split(" | ")[0] == "inexact 1065353217"
    payload = "".join(" ".join(map(str,[prefix,target,intent,pair,*raw]))+"\n"
                      for prefix,target,intent,pair,raw in cases)
    p = subprocess.run([exe],input=payload,text=True,stdout=subprocess.PIPE,check=True)
    actual = p.stdout.splitlines()
    assert len(actual)==len(wanted), (len(actual),len(wanted))
    bad = [(cases[i],a,b) for i,(a,b) in enumerate(zip(actual,wanted)) if a!=b]
    if bad:
        for v in bad[:12]: print("MISMATCH",v)
        raise SystemExit(1)
    counts = Counter(s.split()[0] for v in wanted for s in v.split(" | "))
    print(f"R15 Probe 15 PASS: {len(cases)} API pairs / {2*len(cases)} directional comparisons; {dict(counts)}; real traits {traits}")

if __name__=="__main__": main()
