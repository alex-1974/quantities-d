#!/usr/bin/env python3
"""Independent Fraction quantization for all three identity/inclusion paths."""
from pathlib import Path
import random
import subprocess
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"r15-exact-unit-rescale"))
from oracle import f32_fraction,f64_fraction,target_double

def expected(prefix,raw):
    source=f32_fraction(raw) if prefix=="F" else f64_fraction(raw)
    if source is None: values=["nonFinite -"]*(4 if prefix=="F" else 2)
    elif prefix=="D": values=[f"exact {raw}"]*2
    else:
        widened,overflow=target_double(source)
        assert not overflow and f64_fraction(widened)==source
        if source==0: widened=(raw>>31)<<63
        values=[f"exact {raw}"]*2+[f"exact {widened}"]*2
    return " | ".join(values)

def main():
    fixed_f={0,1,0x80000000,0x007fffff,0x00800000,0x7f7fffff,
             0xff7fffff,0x7f800000,0xff800000,0x7fc00001,0x7f800001}
    # All exponents and both signs, around significand boundary patterns.
    for ef in range(256):
        for fraction in [0,1,0x3fffff,0x400000,0x7ffffe,0x7fffff]:
            for sign in [0,1]: fixed_f.add((sign<<31)|(ef<<23)|fraction)
    for top in range(23):
        for raw in [1<<top,(1<<top)-1,(1<<top)+1]:
            fixed_f.update([raw,raw|0x80000000])
    fixed_d={0,1,1<<63,0x000fffffffffffff,0x0010000000000000,
             0x7fefffffffffffff,0xffefffffffffffff,0x7ff0000000000000,
             0xfff0000000000000,0x7ff8000000000001,0x7ff0000000000001}
    for ef in range(2048):
        for fraction in [0,1,(1<<52)-1]:
            for sign in [0,1]: fixed_d.add((sign<<63)|(ef<<52)|fraction)
    rng=random.Random(0x150018)
    cases=[("F",raw) for raw in sorted(fixed_f)]+[("D",raw) for raw in sorted(fixed_d)]
    cases += [("F",rng.getrandbits(32)) for _ in range(20000)]
    cases += [("D",rng.getrandbits(64)) for _ in range(20000)]
    wanted=[expected(*case) for case in cases]
    payload="".join(f"{prefix} {raw}\n" for prefix,raw in cases)
    actual=subprocess.check_output([sys.argv[1]],input=payload,text=True).splitlines()
    assert len(actual)==len(wanted),(len(actual),len(wanted))
    bad=[(cases[i],a,b) for i,(a,b) in enumerate(zip(actual,wanted)) if a!=b]
    if bad:
        for case in bad[:12]: print("MISMATCH",case)
        raise SystemExit(1)
    comparisons=sum(4 if p=="F" else 2 for p,_ in cases)
    print(f"R15 Probe 18 IDENTITY PASS: {len(cases)} represented inputs / {comparisons} API comparisons, zero mismatches")

if __name__=="__main__": main()
