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


## Observed result

The exhaustive audit passed on both baseline compilers:

- DMD 2.111: checked pairs=64, mismatches=0;
- LDC 1.41: checked pairs=64, mismatches=0.

Both runs exited successfully.

The type-only candidate therefore matches the independent BigInt range oracle
for all 8 x 8 ordered built-in integral type pairs.

## ResultRep rule established by the audit

Because every built-in integral divisor type contains +1, every quotient range
must contain the complete dividend range.

If the divisor type is unsigned, it cannot reverse the sign, so the dividend
Rep itself contains every exact quotient.

If the divisor type is signed, -1 is also available. The result range must then
contain both the dividend range and its negation.

Consequences include:

- int / uint -> int is sufficient;
- int / int -> long, so int.min / -1 becomes representable;
- uint / int -> long because negative quotients are possible;
- signed 64-bit dividends with signed divisors have no universally sufficient
  built-in integral ResultRep;
- unsigned 64-bit dividends with signed divisors likewise have no universally
  sufficient built-in integral ResultRep.

A void ResultRep therefore identifies a static Class-O quotient pair: some
exact mathematical quotient for values in the operand type ranges cannot be
represented by any built-in integral type.

## Scope

This result solves only payload representation for the exact state.

It does not remove runtime classification:

- divisor == 0 -> divisionByZero;
- non-zero divisor with remainder -> inexact;
- exact quotient -> payload if representable under the selected API policy.

The next gate is a Quantity-shaped exact-division prototype using this
ResultRep rule.
