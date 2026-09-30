#!/usr/bin/env python3
from collections import Counter
from fractions import Fraction
import random
import subprocess
import sys

MIN, MAX = -(1 << 63), (1 << 63) - 1

def expected(case):
    intent, mode, sig, e, neg, fn, fd, tn, td = case
    x = Fraction(sig * fn * td, fd * tn)
    x *= Fraction(1 << e) if e >= 0 else Fraction(1, 1 << -e)
    if neg: x = -x
    if x < MIN or x > MAX: return "overflow -"
    if x.denominator == 1: return f"exact {x.numerator}"
    if intent == "C": return "inexact -"
    if mode == 0:
        v = abs(x.numerator) // x.denominator
        if x < 0: v = -v
    elif mode == 1: v = x.numerator // x.denominator
    elif mode == 2: v = -((-x.numerator) // x.denominator)
    else:
        q, r = divmod(abs(x.numerator), x.denominator)
        v = q + (2 * r >= x.denominator)
        if x < 0: v = -v
    assert MIN <= v <= MAX
    return f"inexact {v}"

def main():
    rng = random.Random(0x150012)
    cases = []
    witness = (MAX, MAX-18, MAX-20, MAX-6)
    fixed = []
    # Integer limits, signed zero, ties, and extreme exponent behavior.
    for sig in [0, 1, 2, 3, 5, MAX-1, MAX, 1 << 63, (1 << 64)-1]:
        for e in [0, -1, -2, -16445, 16383]:
            for neg in [0, 1]: fixed.append((sig,e,neg,1,1,1,1))
    for neg in [0,1]:
        for fn,fd in [(MAX,MAX-1),(MAX-1,MAX),(MIN,MAX)]:
            for sig in [MAX,1 << 63]: fixed.append((sig,0,neg,fn,fd,1,1))
        fixed += [((1 << 64)-1,0,neg,*witness),
                  ((1 << 64)-1,-2,neg,*witness),
                  ((1 << 64)-1,0,neg,MAX,MAX-18,MAX,MAX-18),
                  (1,-1,neg,MIN,MAX,1,1),
                  (1,0,neg,1,MAX,MAX,1)]
    for v in fixed:
        cases.append(("C",0,*v))
        cases.extend(("R",m,*v) for m in range(4))
    for i in range(20000):
        sig = rng.choice([0,1,MAX,1 << 63,(1 << 64)-1,rng.getrandbits(64)])
        e = rng.choice([0,-1,-2,-63,63,-16445,16383,rng.randrange(-190,128)])
        factors = [rng.randrange(1,1 << 63) for _ in range(4)]
        if i % 3 == 0: factors = list(witness)
        if i % 7 == 0: factors[2:] = factors[:2]
        if i % 11 == 0: factors[0] = MIN
        if i % 13 == 0: factors[2] = -factors[2]
        cases.append((rng.choice("CR"),rng.randrange(4),sig,e,rng.randrange(2),*factors))
    wanted = [expected(v) for v in cases]
    payload = "".join(" ".join(map(str,v))+"\n" for v in cases)
    p = subprocess.run([sys.argv[1]],input=payload,text=True,stdout=subprocess.PIPE,check=True)
    actual = p.stdout.splitlines()
    assert len(actual) == len(wanted), (len(actual),len(wanted))
    bad = [(cases[i],x,y) for i,(x,y) in enumerate(zip(actual,wanted)) if x != y]
    if bad:
        for v in bad[:12]: print("MISMATCH",v)
        raise SystemExit(1)
    counts = Counter(v.split()[0] for v in wanted)
    print(f"R15 Probe 12 PASS: {len(cases)} exact-rational long comparisons; {dict(counts)}")

if __name__ == "__main__": main()
