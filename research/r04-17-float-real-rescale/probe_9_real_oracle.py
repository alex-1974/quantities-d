#!/usr/bin/env python3

from fractions import Fraction
from pathlib import Path
import random
import subprocess
import sys

P = 64
MIN_NORMAL_TOP = -16382
MAX_TOP = 16383
MIN_SUB_EXP = -16445
MAX_SCALE = (1 << 63) - 1
SEED = 0x41780
COUNT = 10000

def round_even(fr):
    q, r = divmod(fr.numerator, fr.denominator)
    t = 2 * r
    if t > fr.denominator:
        return q + 1
    if t < fr.denominator:
        return q
    return q + (q & 1)

def floor_log2(fr):
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

def canonical(fr):
    neg = fr < 0
    x = -fr if neg else fr

    if x == 0:
        return "-zero" if neg else "+zero"

    e = floor_log2(x)

    if e > MAX_TOP:
        return "-inf" if neg else "+inf"

    if e >= MIN_NORMAL_TOP:
        shift = (P - 1) - e
        scaled = x * (1 << shift) if shift >= 0 else x / (1 << (-shift))
        sig = round_even(scaled)

        if sig == (1 << P):
            sig >>= 1
            e += 1
            if e > MAX_TOP:
                return "-inf" if neg else "+inf"

        exp2 = e - (P - 1)
        return f"{'-' if neg else '+'} {sig} {exp2}"

    quanta = round_even(x / Fraction(1, 1 << (-MIN_SUB_EXP)))

    if quanta == 0:
        return "-zero" if neg else "+zero"

    # min normal is representable as significand 2^(P-1) at MIN_SUB_EXP.
    if quanta > (1 << (P - 1)):
        raise AssertionError(quanta)

    return f"{'-' if neg else '+'} {quanta} {MIN_SUB_EXP}"

def represented(sig, exp2):
    if exp2 >= 0:
        return Fraction(sig << exp2, 1)
    return Fraction(sig, 1 << (-exp2))

def expected(op, ls, le, rs, re, n, d):
    lhs = represented(ls, le)
    rhs = represented(rs, re)
    scale = Fraction(n, d)
    value = lhs * rhs * scale if op == "P" else lhs / rhs * scale
    return canonical(value)

def main():
    exe = sys.argv[1]
    path = Path(sys.argv[2])
    rng = random.Random(SEED)

    cases = []

    # Boundary-oriented fixed cases.
    top = (1 << 64) - 1
    one = 1 << 63
    fixed = [
        ("P", one, -63, one, -63, 2, 3),
        ("Q", one, -63, one, -63, 2, 3),
        ("P", top, MAX_TOP - 63, one, 1, 1, 2),
        ("Q", top, MAX_TOP - 63, one, -1, 1, 2),
        ("P", one, MIN_SUB_EXP, one, -62, 1, 2),
        ("Q", one, MIN_SUB_EXP, one, -64, 1, 2),
    ]
    cases.extend(fixed)

    for _ in range(COUNT):
        op = "P" if rng.getrandbits(1) == 0 else "Q"
        ls = rng.getrandbits(64) | (1 << 63)
        rs = rng.getrandbits(64) | (1 << 63)

        # Keep represented inputs finite normal for randomized differential
        # coverage; fixed vectors cover extreme/subnormal output boundaries.
        le = rng.randint(-1063, 937)
        re = rng.randint(-1063, 937)

        if rng.randrange(4) == 0:
            n = rng.randrange(1, 1 << 20)
            d = rng.randrange(1, 1 << 20)
        else:
            n = rng.randrange(1, MAX_SCALE + 1)
            d = rng.randrange(1, MAX_SCALE + 1)

        cases.append((op, ls, le, rs, re, n, d))

    lines = [
        f"{op} {ls} {le} {rs} {re} {n} {d}"
        for op, ls, le, rs, re, n, d in cases
    ]
    expected_values = [expected(*c) for c in cases]

    path.write_text("\n".join(lines) + "\n")

    proc = subprocess.run(
        [exe],
        input=path.read_text(),
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
            mismatches.append((i, lines[i], a, e))
            if len(mismatches) >= 10:
                break

    if mismatches:
        for m in mismatches:
            print("MISMATCH", m)
        raise SystemExit(1)

    print(
        f"R04.17 Probe 9 PASS: {len(cases)} "
        "layout-free real80 exact-rational comparisons"
    )

if __name__ == "__main__":
    main()
