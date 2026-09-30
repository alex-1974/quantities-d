#!/usr/bin/env python3
from collections import Counter
from fractions import Fraction
from pathlib import Path
import random
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"r15-exact-unit-rescale"))
from oracle import f32_fraction, f64_fraction

MIN, MAX = -(1 << 63), (1 << 63)-1

def expected(case):
    prefix, intent, mode, raw, factors = case
    if prefix in "NPM": return "nonFinite -"
    if prefix == "F": source = f32_fraction(raw[0])
    elif prefix == "D": source = f64_fraction(raw[0])
    else:
        sig,e,neg = raw
        source = Fraction(sig << e) if e >= 0 else Fraction(sig,1 << -e)
        if neg: source = -source
    if source is None: return "nonFinite -"
    fn,fd,tn,td = factors
    x = source * Fraction(fn*td,fd*tn)
    if x < MIN or x > MAX: return "overflow -"
    if x.denominator == 1: return f"exact {x.numerator}"
    if intent == "C": return "inexact -"
    if mode == 0: v = int(x)
    elif mode == 1: v = x.numerator // x.denominator
    elif mode == 2: v = -((-x.numerator) // x.denominator)
    else:
        v = (abs(x.numerator)*2+x.denominator)//(x.denominator*2)
        if x < 0: v = -v
    assert MIN <= v <= MAX
    return f"inexact {v}"

def main():
    exe = sys.argv[1]
    traits = tuple(map(int,subprocess.check_output([exe,"--traits"],text=True).split()))
    real_ok = traits in ((64,-16381,16384),(53,-1021,1024))
    rng = random.Random(0x150013)
    cases = []
    ratios = [(1,1,1,1),(2,3,1,1),(3,2,1,1),(-3,2,1,1),
              (381,1250,1200,3937),(MIN,MAX,1,1),
              (MAX,MAX-18,MAX-20,MAX-6),(MAX,MAX-18,MAX,MAX-18),
              (1,MAX,MAX,1),(MAX,1,1,MAX)]
    fixed = []
    for prefix,raws in [
        ("F",[0,1,0x80000000,0x007fffff,0x00800000,0x3f000000,
              0x3fc00000,0xbfc00000,0x5effffff,0x5f000000,0xdf000000,
              0x7f7fffff,0xff7fffff,0x7f800000,0xff800000,
              0x7fc00001,0x7f800001,0xff800001]),
        ("D",[0,1,1 << 63,0x000fffffffffffff,0x0010000000000000,
              0x3fe0000000000000,0x3ff8000000000000,0xbff8000000000000,
              0x43dfffffffffffff,0x43e0000000000000,0xc3e0000000000000,
              0x7fefffffffffffff,0xffefffffffffffff,0x7ff0000000000000,
              0xfff0000000000000,0x7ff8000000000001,0x7ff0000000000001,
              0xfff0000000000001])]:
        fixed.extend((prefix,[v]) for v in raws)
    if real_ok:
        p,mi,ma = traits
        values = [(0,0),(1,mi-p),(2,mi-p),((1 << (p-1))-1,mi-p),
                  (1 << (p-1),mi-p),((1 << p)-1,ma-p),
                  (1,63),(3,-1),(1,-1)]
        if p == 64: values += [(MAX,0),((1 << 64)-1,-1),((1 << 64)-3,-1)]
        fixed.extend(("R",[sig,e,neg]) for sig,e in values for neg in [0,1])
        fixed.extend((prefix,[]) for prefix in "NPM")
    for prefix,raw in fixed:
        for factors in ratios:
            cases.append((prefix,"C",0,raw,factors))
            cases.extend((prefix,"R",m,raw,factors) for m in range(4))
    for i in range(20000):
        prefix = rng.choice("FD"+("R" if real_ok else ""))
        if prefix == "F": raw = [rng.getrandbits(32)]
        elif prefix == "D": raw = [rng.getrandbits(64)]
        else:
            p,mi,ma = traits
            sig = rng.choice([1,(1 << p)-1,rng.randrange(1,1 << p)])
            e = rng.choice([mi-p,ma-p,-1,-63,0,rng.randrange(mi-p,ma-p+1)])
            raw = [sig,e,rng.randrange(2)]
        if i % 2: factors = rng.choice(ratios)
        else:
            fn = rng.randrange(1,1 << 63)*rng.choice([-1,1])
            tn = rng.randrange(1,1 << 63)*rng.choice([-1,1])
            factors = (fn,rng.randrange(1,1 << 63),tn,rng.randrange(1,1 << 63))
        cases.append((prefix,rng.choice("CR"),rng.randrange(4),raw,factors))
    wanted = [expected(v) for v in cases]
    payload = "".join(" ".join(map(str,[prefix,intent,mode,*raw,*factors]))+"\n"
                      for prefix,intent,mode,raw,factors in cases)
    result = subprocess.run([exe],input=payload,text=True,stdout=subprocess.PIPE,check=True)
    actual = result.stdout.splitlines()
    assert len(actual) == len(wanted), (len(actual),len(wanted))
    bad = [(cases[i],a,b) for i,(a,b) in enumerate(zip(actual,wanted)) if a != b]
    if bad:
        for v in bad[:12]: print("MISMATCH",v)
        raise SystemExit(1)
    counts = Counter(v.split()[0] for v in wanted)
    print(f"R15 Probe 13 PASS: {len(cases)} represented floating-source to long comparisons; {dict(counts)}; real traits {traits}")

if __name__ == "__main__": main()
