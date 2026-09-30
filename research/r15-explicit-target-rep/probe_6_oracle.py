#!/usr/bin/env python3

from fractions import Fraction
import random
import struct
import subprocess
import sys

SEED = 0x150006
COUNT = 12000
LONG_MIN = -(1 << 63)
LONG_MAX = (1 << 63) - 1
REAL_P = 64
REAL_MIN_NORMAL = -16382
REAL_MAX_TOP = 16383
REAL_MIN_SUB = -16445

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

def represented(sig, exp2, neg=False):
    v = Fraction(sig << exp2, 1) if exp2 >= 0 else Fraction(sig, 1 << (-exp2))
    return -v if neg else v

def canonical_parts(fr):
    if fr == 0:
        return (0, 0, 0)

    neg = fr < 0
    x = -fr if neg else fr

    # Inputs/results in this probe are already exactly representable in real80
    # for LR/DR; normalize the exact rational to odd significand + exponent.
    n = x.numerator
    d = x.denominator

    assert d & (d - 1) == 0
    exp2 = -(d.bit_length() - 1)

    while n % 2 == 0:
        n //= 2
        exp2 += 1

    return (1 if neg else 0, n, exp2)

def round_even(fr):
    q, r = divmod(fr.numerator, fr.denominator)
    twice = 2 * r
    if twice > fr.denominator:
        return q + 1
    if twice < fr.denominator:
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

def round_binary64(fr):
    neg = fr < 0
    x = -fr if neg else fr
    sign = (1 << 63) if neg else 0

    if x == 0:
        return sign, False

    e = floor_log2(x)
    if e > 1023:
        return sign | (0x7ff << 52), True

    if e >= -1022:
        shift = 52 - e
        scaled = x * (1 << shift) if shift >= 0 else x / (1 << (-shift))
        sig = round_even(scaled)

        if sig == (1 << 53):
            sig >>= 1
            e += 1
            if e > 1023:
                return sign | (0x7ff << 52), True

        return sign | ((e + 1023) << 52) | (sig - (1 << 52)), False

    quanta = round_even(x * (1 << 1074))
    if quanta == 0:
        return sign, False
    if quanta >= (1 << 52):
        return sign | (1 << 52), False
    return sign | quanta, False

def finite_f64(rng):
    while True:
        bits = rng.getrandbits(64)
        if ((bits >> 52) & 0x7ff) != 0x7ff:
            return bits

def expected(case):
    op = case[0]

    if op == "LR":
        value = int(case[1])
        fr = Fraction(value)
        neg, sig, exp = canonical_parts(fr)
        if value == 0:
            return "exact zero 0"
        return f"exact {neg} {sig} {exp}"

    if op == "DR":
        bits = int(case[1])
        fr = f64_fraction(bits)

        if fr is None:
            return "nonFinite -"

        if fr == 0:
            neg = 1 if (bits >> 63) else 0
            return f"exact zero {neg}"

        neg, sig, exp = canonical_parts(fr)
        return f"exact {neg} {sig} {exp}"

    _, neg_s, sig_s, exp_s = case
    neg = bool(int(neg_s))
    sig = int(sig_s)
    exp2 = int(exp_s)
    fr = represented(sig, exp2, neg)

    if op == "RD":
        bits, overflow = round_binary64(fr)
        if overflow:
            return "overflow -"
        status = "exact" if f64_fraction(bits) == fr else "inexact"
        return f"{status} {bits}"

    assert op == "RL"

    if fr < LONG_MIN or fr > LONG_MAX:
        return "overflow -"
    if fr.denominator != 1:
        return "inexact -"
    return f"exact {fr.numerator}"

def main():
    exe = sys.argv[1]
    rng = random.Random(SEED)

    cases = []

    for x in [
        LONG_MIN, LONG_MAX, -1, 0, 1,
        (1 << 53) + 1,
        (1 << 63) - 1,
    ]:
        cases.append(("LR", str(x)))

    for bits in [
        0x0000000000000000,
        0x8000000000000000,
        0x0000000000000001,
        0x0010000000000000,
        0x3ff0000000000000,
        0x3ff0000000000001,
        0x7fefffffffffffff,
        0x7ff0000000000000,
        0xfff0000000000000,
        0x7ff8000000000001,
    ]:
        cases.append(("DR", str(bits)))

    # Current-real represented values. Keep a full 64-bit significand for
    # normal-like coverage and vary exponent enough to cover double exact,
    # inexact, overflow, and long conversion classes.
    fixed_real = [
        (0, 1 << 63, -63),
        (1, 1 << 63, -63),
        (0, (1 << 63) + 1, -63),
        (0, (1 << 63) + 1, -64),
        (0, (1 << 64) - 1, 960),
        (0, 1 << 63, -16445),
        (0, 1 << 63, 0),
        (1, 1 << 63, 0),
    ]
    for neg, sig, exp in fixed_real:
        cases.append(("RD", str(neg), str(sig), str(exp)))
        cases.append(("RL", str(neg), str(sig), str(exp)))

    for _ in range(COUNT):
        kind = rng.randrange(4)

        if kind == 0:
            cases.append(("LR", str(rng.randrange(LONG_MIN, LONG_MAX + 1))))
        elif kind == 1:
            cases.append(("DR", str(finite_f64(rng))))
        else:
            neg = rng.randrange(2)
            sig = rng.getrandbits(64) | (1 << 63)
            exp = rng.randint(-1200, 1100)
            op = "RD" if kind == 2 else "RL"
            cases.append((op, str(neg), str(sig), str(exp)))

    payload = "\n".join(" ".join(c) for c in cases) + "\n"
    expected_values = [expected(c) for c in cases]

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

    print(f"R15 Probe 6 PASS: {len(cases)} real identity-scale conversion comparisons")

if __name__ == "__main__":
    main()
