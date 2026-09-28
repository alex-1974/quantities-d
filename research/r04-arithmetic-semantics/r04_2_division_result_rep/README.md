# R04.2.13 — Exact integral quotient ResultRep

## Goal

Determine the smallest built-in integral Rep that can contain every **exact
integral quotient** produced by an operand type pair.

This is not a raw-D division result-type study.

The mathematical domain is:

- dividend: every value representable by A;
- divisor: every non-zero value representable by B;
- only pairs whose mathematical quotient is integral contribute a payload
  value;
- non-integral quotients are `inexact`;
- zero divisors are `divisionByZero`.

The ResultRep must contain every quotient that can appear in the exact state.

## Important distinction

For division, the static result range is not obtained by simply dividing type
endpoints. The largest quotient magnitude is normally reached at divisors
`+1` or `-1` when those values exist.

Signedness matters because a signed divisor can reverse the sign of the
dividend.

Examples:

- int / int can produce `-int.min`, so int itself is insufficient;
- int / uint cannot reverse sign, but divisor 1 preserves the complete int
  range;
- uint / int can produce negative values because divisor -1 exists;
- ulong / signed integral may require a positive or negative magnitude beyond
  long.

## Research method

1. derive an exact mathematical quotient range from operand type ranges;
2. choose the smallest built-in D integral type containing that range;
3. independently verify the candidate against a BigInt oracle;
4. cover all 8 x 8 ordered pairs of:
   byte, ubyte, short, ushort, int, uint, long, ulong.

BigInt is research-only and must not enter the production arithmetic path.

## Oracle simplification

For the complete exact quotient range it is sufficient to consider whether the
divisor type contains +1 and/or -1:

- every built-in integral type contains +1;
- signed built-in integral types contain -1;
- division by a divisor with absolute value > 1 cannot increase dividend
  magnitude.

Thus the quotient extrema are induced by division by +1 and, for signed B, -1.

The probe nevertheless computes those extrema with BigInt and compares them
against a type-only candidate.

## Acceptance

All 64 ordered type pairs must match the independent exact-range oracle on DMD
2.111 and LDC 1.41.

A `void` ResultRep means no built-in integral type can represent every exact
quotient for that operand-type pair.
