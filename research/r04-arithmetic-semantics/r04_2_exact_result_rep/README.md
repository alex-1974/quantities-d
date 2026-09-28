# R04.2.7 — Exact type-only ResultRep derivation

## Goal

Derive AddRep, SubRep, and MulRep from integer type properties only, while
matching the exact BigInt range reference.

No endpoint arithmetic in the production candidate may itself overflow.

## Key observation

For the D built-in integer types, every endpoint has the form:

- signed n-bit: min = -2^(n-1), max = 2^(n-1)-1
- unsigned n-bit: min = 0, max = 2^n-1

Therefore operation ranges can be classified by signedness and operand bit
widths without materializing the potentially overflowing endpoint values.

## Selection rule

The desired ResultRep is the smallest built-in type whose mathematical range
contains the complete operation range.

This is deliberately not the same as preserving operand signedness.

## Addition

Let SA/SB mean signed operands and ua/ub their unsigned widths.

Cases:

- U + U: range 0 .. (2^a-1)+(2^b-1)
- S + S: range -2^(a-1)-2^(b-1) .. (2^(a-1)-1)+(2^(b-1)-1)
- S + U: range -2^(s-1) .. (2^(s-1)-1)+(2^u-1)

The required positive and negative magnitudes can be represented as bit-count
requirements rather than endpoint values.

## Subtraction

Subtraction is asymmetric:

- U - U can be negative;
- S - U and U - S have different extrema.

It therefore requires its own trait rather than reusing AddRep.

## Multiplication

Endpoint signs determine whether the range is non-negative or signed.

For powers-of-two endpoint structure, required magnitude bits derive from the
sum of operand value widths, with special handling for signed minima because
|min| is one larger than max.

## Acceptance gate

The candidate is accepted only if it matches the BigInt reference for all
64 ordered built-in Rep pairs and all three operations: 192/192 exact matches.

A mismatch is evidence that the formula is incomplete; the reference remains
authoritative for this research stage.
