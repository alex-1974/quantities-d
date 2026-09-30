#!/usr/bin/env python3

from fractions import Fraction
import random
import struct
import subprocess
import sys

SEED = 0x150005
N = 16000
LONG_MIN = -(1 << 63)
LONG_MAX = (1 << 63) - 1

def f32_fraction(bits):
    sign = -1 if (bits >> 31) else 1
    exp = (bits >> 23) & 0xff
    frac = bits & 0x7fffff
    if exp == 0xff:
        return None
    if exp == 0:
        if frac == 0:
            return Fraction(0)
        sig, e = frac, -149
    else:
        sig, e = (1 << 23) | frac, exp - 150
    v = Fraction(sig << e, 1) if e >= 0 else Fraction(sig, 1 << (-e))
    return sign * v

def f64_fraction(bits):
    sign = -1 if (bits >> 63) else 1
    exp = (bits >> 52) & 0x7ff
    frac = bits & ((1 << 52) - 1)
    if exp == 0x7ff:
        return None
    if exp == 0:
        if frac == 0:
            return Fraction(0)
        sig, e = frac, -1074
    else:
        sig, e = (1 << 52) | frac, exp - 1075
    v = Fraction(sig << e, 1) if e >= 0 else Fraction(sig, 1 << (-e))
    return sign * v

def round_even(fr):
    q, r = divmod(fr.numerator, fr.denominator)
    t = r * 2
    if t > fr.denominator:
        return q + 1
    if t < fr.denominator:
        return q
    return q + (q & 1)

def floor_log2(fr):
    p, q = fr.numerator, fr.denominator
    e = p.bit_length() - q.bit_length()
    if e >= 0:
        if p < (q << e):
            e -= 1
    elif (p << (-e)) < q:
        e -= 1
    return e

def round_binary(fr, p, emin_normal, emax, emin_sub, exp_bits):
    neg = fr < 0
    x = -fr if neg else fr
    sign_shift = 31 if p == 24 else 63
    frac_bits = p - 1
    sign = (1 << sign_shift) if neg else 0

    if x == 0:
        return sign, False

    e = floor_log2(x)
    if e > emax:
        inf_exp = (1 << exp_bits) - 1
        return sign | (inf_exp << frac_bits), True

    if e >= emin_normal:
        shift = frac_bits - e
        scaled = x * (1 << shift) if shift >= 0 else x / (1 << (-shift))
        sig = round_even(scaled)
        if sig == (1 << p):
            sig >>= 1
            e += 1
            if e > emax:
                inf_exp = (1 << exp_bits) - 1
                return sign | (inf_exp << frac_bits), True
        bias = 127 if p == 24 else 1023
        return sign | ((e + bias) << frac_bits) | (sig - (1 << frac_bits)), False

    quanta = round_even(x * (1 << (-emin_sub)))
    if quanta == 0:
        return sign, False
    if quanta >= (1 << frac_bits):
        return sign | (1 << frac_bits), False
    return sign | quanta, False

def target_float(fr):
    return round_binary(fr, 24, -126, 127, -149, 8)

def target_double(fr):
    return round_binary(fr, 53, -1022, 1023, -1074, 11)


def expected_case(op, raw, n, d):
    if op[0] == "L" or op[0] == "U":
        source = Fraction(int(raw[0]))
        negative = source < 0
    elif op[0] == "R":
        sig, e, sign = map(int, raw)
        source = Fraction(sig << e) if e >= 0 else Fraction(sig, 1 << -e)
        if sign: source = -source
        negative = bool(sign)
    else:
        bits = int(raw[0])
        source = f32_fraction(bits) if op[0] == "F" else f64_fraction(bits)
        negative = bool(bits >> (31 if op[0] == "F" else 63))
    if source is None:
        return "nonFinite -"
    target = source * Fraction(n, d)
    is_float = op[1] == "F"
    max_value = f32_fraction(0x7f7fffff) if is_float else f64_fraction(0x7fefffffffffffff)
    if abs(target) > max_value:
        return "overflow -"
    out, overflow = target_float(target) if is_float else target_double(target)
    assert not overflow
    if target == 0:
        out = int(negative != (n < 0)) << (31 if is_float else 63)
    represented = f32_fraction(out) if is_float else f64_fraction(out)
    return f'{"exact" if represented == target else "inexact"} {out}'

def main():
    exe = sys.argv[1]
    traits = tuple(map(int, subprocess.check_output([exe, "--traits"], text=True).split()))
    real_ok = traits in ((64, -16381, 16384), (53, -1021, 1024))
    rng = random.Random(0x150010)
    cases = []
    ratios = [(1,1),(2,3),(3,2),(381,1250),(1200,3937),
              ((1<<62)+1,1<<62),(1<<62,(1<<62)+1),
              ((1<<60)+(1<<36)+1,1<<60),
              ((1<<63)-1,1),(-(1<<63),1),(-3,2),(0,1)]
    for prefix, raws in [
        ("L", [0,1,-1,LONG_MIN,LONG_MAX,(1<<53)+1]),
        ("U", [0,1,(1<<63),(1<<64)-1]),
        ("F", [0,1,0x80000000,0x007fffff,0x00800000,0x3f800000,
               0x7f7fffff,0xff7fffff,0x7f800000,0xff800000,0x7fc00001]),
        ("D", [0,1,1<<63,0x000fffffffffffff,0x0010000000000000,
               0x3ff0000000000000,0x7fefffffffffffff,0xffefffffffffffff,
               0x7ff0000000000000,0xfff0000000000000,0x7ff8000000000001])]:
        for target in "FD":
            for raw in raws:
                for n,d in ratios:
                    cases.append((prefix+target,[str(raw)],n,d))
    if real_ok:
        p, mi, ma = traits
        for target in "FD":
            for sig,e in [(0,0),(1,mi-p),((1<<p)-1,ma-p),(1<<(p-1),1-p)]:
                for sign in (0,1):
                    for n,d in ratios:
                        cases.append(("R"+target,list(map(str,(sig,e,sign))),n,d))
    sources = "LUFD" + ("R" if real_ok else "")
    for i in range(20000):
        prefix = rng.choice(sources)
        target = rng.choice("FD")
        if prefix == "L": raw=[str(rng.randrange(LONG_MIN,LONG_MAX+1))]
        elif prefix == "U": raw=[str(rng.getrandbits(64))]
        elif prefix == "F": raw=[str(rng.getrandbits(32))]
        elif prefix == "D": raw=[str(rng.getrandbits(64))]
        else:
            p,mi,ma = traits
            raw=list(map(str,(rng.randrange(1<<(p-1),1<<p),
                rng.choice([mi-p,ma-p,-149,-1074,0,rng.randrange(mi-p,ma-p+1)]),
                rng.randrange(2))))
        if i%2: n,d=rng.choice(ratios)
        else: n,d=rng.randrange(-(1<<63),(1<<63)),rng.randrange(1,1<<63)
        cases.append((prefix+target,raw,n,d))
    # Explicit direct-rounding witness and both mathematical range boundaries.
    payload="".join(f"{op} {' '.join(raw)} {n} {d}\n" for op,raw,n,d in cases)
    expected=[expected_case(*case) for case in cases]
    proc=subprocess.run([exe],input=payload,text=True,stdout=subprocess.PIPE,check=True)
    actual=proc.stdout.splitlines()
    assert len(actual)==len(expected),(len(actual),len(expected))
    failures=[(cases[i],a,b) for i,(a,b) in enumerate(zip(actual,expected)) if a!=b]
    if failures:
        for item in failures[:12]: print("MISMATCH",item)
        raise SystemExit(1)
    print(f"R15 Probe 10 PASS: {len(cases)} exact Unit-scale mixed-Rep comparisons; real traits {traits}")

if __name__ == "__main__":
    main()

