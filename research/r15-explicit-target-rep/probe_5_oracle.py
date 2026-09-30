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

def status_name(name):
    return name

def expected(op, raw):
    if op == "LF":
        source = int(raw)
        fr = Fraction(source)
        bits, overflow = target_float(fr)
        assert not overflow
        represented = f32_fraction(bits)
        status = "exact" if represented == fr else "inexact"
        return f"{status} {bits}"

    if op == "LD":
        source = int(raw)
        fr = Fraction(source)
        bits, overflow = target_double(fr)
        assert not overflow
        represented = f64_fraction(bits)
        status = "exact" if represented == fr else "inexact"
        return f"{status} {bits}"

    bits = int(raw)
    fr = f32_fraction(bits) if op[0] == "F" else f64_fraction(bits)

    if fr is None:
        return "nonFinite 0"

    if op == "FD":
        out, overflow = target_double(fr)
        assert not overflow
        status = "exact" if f64_fraction(out) == fr else "inexact"
        return f"{status} {out}"

    if op == "DF":
        out, overflow = target_float(fr)
        if overflow:
            return "overflow 0"
        status = "exact" if f32_fraction(out) == fr else "inexact"
        return f"{status} {out}"

    assert op in ("FL", "DL")

    if fr < LONG_MIN or fr > LONG_MAX:
        return "overflow 0"

    if fr.denominator != 1:
        return "inexact 0"

    return f"exact {fr.numerator}"

def finite_random_f32(rng):
    while True:
        x = rng.getrandbits(32)
        if ((x >> 23) & 0xff) != 0xff:
            return x

def finite_random_f64(rng):
    while True:
        x = rng.getrandbits(64)
        if ((x >> 52) & 0x7ff) != 0x7ff:
            return x

def main():
    exe = sys.argv[1]
    rng = random.Random(SEED)

    cases = []

    longs = [
        0, 1, -1,
        (1 << 24) - 1, 1 << 24, (1 << 24) + 1,
        (1 << 53) - 1, 1 << 53, (1 << 53) + 1,
        LONG_MIN, LONG_MAX,
    ]
    for x in longs:
        cases.append(("LF", str(x)))
        cases.append(("LD", str(x)))

    f32_fixed = [
        0x00000000, 0x80000000, 0x00000001, 0x007fffff,
        0x00800000, 0x3f800000, 0x4b000001, 0x7f7fffff,
        0x7f800000, 0xff800000, 0x7fc00001,
    ]
    for b in f32_fixed:
        cases.append(("FD", str(b)))
        cases.append(("FL", str(b)))

    f64_fixed = [
        0x0000000000000000, 0x8000000000000000,
        0x0000000000000001, 0x000fffffffffffff,
        0x0010000000000000, 0x3ff0000000000000,
        0x3ff0000000000001, 0x4330000000000001,
        0x43e0000000000000, 0x7fefffffffffffff,
        0x7ff0000000000000, 0xfff0000000000000,
        0x7ff8000000000001,
    ]
    for b in f64_fixed:
        cases.append(("DF", str(b)))
        cases.append(("DL", str(b)))

    for _ in range(N):
        which = rng.randrange(6)
        if which == 0:
            cases.append(("LF", str(rng.randrange(LONG_MIN, LONG_MAX + 1))))
        elif which == 1:
            cases.append(("LD", str(rng.randrange(LONG_MIN, LONG_MAX + 1))))
        elif which == 2:
            cases.append(("FD", str(finite_random_f32(rng))))
        elif which == 3:
            cases.append(("DF", str(finite_random_f64(rng))))
        elif which == 4:
            cases.append(("FL", str(finite_random_f32(rng))))
        else:
            cases.append(("DL", str(finite_random_f64(rng))))

    payload = "\n".join(f"{op} {raw}" for op, raw in cases) + "\n"
    expected_values = [expected(op, raw) for op, raw in cases]

    proc = subprocess.run(
        [exe],
        input=payload,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    )
    actual = [x.strip() for x in proc.stdout.splitlines() if x.strip()]

    if len(actual) != len(expected_values):
        raise SystemExit(f"count mismatch {len(actual)} != {len(expected_values)}")

    mismatches = []
    for i, (a, e) in enumerate(zip(actual, expected_values)):
        if a != e:
            mismatches.append((i, cases[i], a, e))
            if len(mismatches) >= 12:
                break

    if mismatches:
        for m in mismatches:
            print("MISMATCH", m)
        raise SystemExit(1)

    print(f"R15 Probe 5 PASS: {len(cases)} identity-scale conversion comparisons")

if __name__ == "__main__":
    main()
