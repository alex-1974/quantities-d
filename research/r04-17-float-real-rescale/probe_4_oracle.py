#!/usr/bin/env python3

from fractions import Fraction
from pathlib import Path
import random
import subprocess
import sys

COUNT = 12000
SEED = 0x41717
MAX_SCALE = (1 << 63) - 1

def float_fraction(bits: int) -> Fraction:
    sign = -1 if bits >> 31 else 1
    exp = (bits >> 23) & 0xff
    frac = bits & 0x7fffff
    assert exp != 0xff

    if exp == 0:
        assert frac != 0
        sig = frac
        e = -149
    else:
        sig = (1 << 23) | frac
        e = exp - 150

    if e >= 0:
        value = Fraction(sig << e, 1)
    else:
        value = Fraction(sig, 1 << (-e))

    return sign * value

def round_even_fraction(fr: Fraction) -> int:
    assert fr >= 0
    q, r = divmod(fr.numerator, fr.denominator)
    twice = r * 2
    if twice > fr.denominator:
        return q + 1
    if twice < fr.denominator:
        return q
    return q + (q & 1)

def floor_log2_fraction(fr: Fraction) -> int:
    assert fr > 0
    p = fr.numerator
    q = fr.denominator
    e = p.bit_length() - q.bit_length()
    if e >= 0:
        if p < (q << e):
            e -= 1
    else:
        if (p << (-e)) < q:
            e -= 1
    return e

def round_binary32(fr: Fraction) -> int:
    negative = fr < 0
    x = -fr if negative else fr
    sign = (1 << 31) if negative else 0

    if x == 0:
        return sign

    e = floor_log2_fraction(x)

    if e > 127:
        return sign | 0x7f800000

    if e >= -126:
        shift = 23 - e
        if shift >= 0:
            scaled = x * (1 << shift)
        else:
            scaled = x / (1 << (-shift))

        sig = round_even_fraction(scaled)

        if sig == (1 << 24):
            sig >>= 1
            e += 1
            if e > 127:
                return sign | 0x7f800000

        assert (1 << 23) <= sig < (1 << 24)
        return sign | ((e + 127) << 23) | (sig - (1 << 23))

    quanta = round_even_fraction(x * (1 << 149))

    if quanta == 0:
        return sign
    if quanta >= (1 << 23):
        assert quanta == (1 << 23)
        return sign | (1 << 23)

    return sign | quanta

def finite_nonzero_bits(rng: random.Random) -> int:
    while True:
        bits = rng.getrandbits(32)
        exp = (bits >> 23) & 0xff
        frac = bits & 0x7fffff
        if exp != 0xff and (exp != 0 or frac != 0):
            return bits

def build_case(op, lhs_bits, rhs_bits, n, d):
    lhs = float_fraction(lhs_bits)
    rhs = float_fraction(rhs_bits)
    scale = Fraction(n, d)

    if op == "P":
        exact = lhs * rhs * scale
    else:
        exact = lhs / rhs * scale

    return round_binary32(exact)

def main():
    exe = sys.argv[1]
    cases_path = Path(sys.argv[2])

    rng = random.Random(SEED)
    lines = []
    expected = []

    # Boundary-oriented fixed cases, including the double-rounding witness.
    d = 1 << 60
    n = d + (1 << 36) + 1

    fixed = [
        ("P", 0x3f800000, 0x3f800000, n, d),
        ("P", 0x7f7fffff, 0x40000000, 1, 2),
        ("P", 0x00000001, 0x40000000, 1, 2),
        ("Q", 0x7f7fffff, 0x3f000000, 1, 2),
        ("Q", 0x00000001, 0x3f000000, 1, 2),
        ("P", 0x3fc00000, 0x40000000, 2, 3),
        ("Q", 0x40400000, 0x40000000, 2, 3),
    ]

    for case in fixed:
        op, a, b, num, den = case
        lines.append(f"{op} {a} {b} {num} {den}")
        expected.append(build_case(*case))

    for _ in range(COUNT):
        op = "P" if rng.getrandbits(1) == 0 else "Q"
        a = finite_nonzero_bits(rng)
        b = finite_nonzero_bits(rng)

        # Exercise both small and near-63-bit rational scales.
        if rng.randrange(4) == 0:
            num = rng.randrange(1, 1 << 20)
            den = rng.randrange(1, 1 << 20)
        else:
            num = rng.randrange(1, MAX_SCALE + 1)
            den = rng.randrange(1, MAX_SCALE + 1)

        lines.append(f"{op} {a} {b} {num} {den}")
        expected.append(build_case(op, a, b, num, den))

    cases_path.write_text("\n".join(lines) + "\n")

    proc = subprocess.run(
        [exe],
        input=cases_path.read_text(),
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    )

    actual = [int(x) for x in proc.stdout.splitlines() if x.strip()]

    if len(actual) != len(expected):
        raise SystemExit(
            f"count mismatch: actual={len(actual)} expected={len(expected)}"
        )

    mismatches = []
    for i, (a, e) in enumerate(zip(actual, expected)):
        if a != e:
            mismatches.append((i, lines[i], a, e))
            if len(mismatches) >= 10:
                break

    if mismatches:
        for item in mismatches:
            print("MISMATCH", item)
        raise SystemExit(1)

    print(
        f"R04.17 Probe 4 PASS: {len(expected)} "
        "exact-rational binary32 product/quotient comparisons"
    )

if __name__ == "__main__":
    main()
