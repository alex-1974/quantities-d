#!/usr/bin/env python3
"""Independent exact-rational check of the range-first policy witnesses."""
from fractions import Fraction

a = 1 << 62
ratio = Fraction(a-1,a) / Fraction(a,a+1)
upper = (1 << 63)*ratio
lower = Fraction(-(1 << 63),1)/ratio
assert ratio == 1-Fraction(1,1 << 124)
assert upper == (1 << 63)-Fraction(1,1 << 61)
assert (1 << 63)-1 < upper < (1 << 63)
assert int(upper) == (1 << 63)-1
assert lower < -(1 << 63)
assert int(lower) == -(1 << 63)
print("R15 Probe 16 Fraction witnesses PASS: out-of-range exact values truncate to in-range endpoints")
