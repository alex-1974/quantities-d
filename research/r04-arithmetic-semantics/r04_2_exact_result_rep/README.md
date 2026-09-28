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


## Final observed result — DMD 2.111 / LDC 1.41, x86_64

The corrected type-only derivation matches the independent BigInt reference
exactly on both baseline compilers:

```text
checked pairs=64 operations=192 mismatches=0
```

This covers every ordered pair drawn from:

- byte;
- ubyte;
- short;
- ushort;
- int;
- uint;
- long;
- ulong.

and independently covers:

- addition;
- subtraction;
- multiplication.

## R04.2.7 conclusion

The operation-safe integral ResultRep can be derived entirely from compile-time
type properties.

The accepted research model requires no BigInt in the candidate arithmetic
path and does not evaluate overflowing integer endpoints.

The derivation is operation-specific:

- AddRep models the complete mathematical sum range;
- SubRep independently models the asymmetric mathematical difference range;
- MulRep models all multiplication extrema.

The selected result is the smallest supported built-in integer type containing
the complete mathematical result range. If no such built-in type exists, the
operation belongs to Class O and the plain operator is unavailable.

The BigInt implementation remains a research oracle, not production machinery.

### Established invariant

For the audited built-in integer Rep family:

> If a Class-W integral operator is admitted by the ResultRep trait, every
> mathematical result representable by the operand type ranges fits the selected
> built-in ResultRep.

This invariant is now exhaustively checked across 192 type/operation cases on
both baseline compilers.

## Promotion gate

Before production use, apply these exact traits to a Quantity-shaped wrapper
and verify:

1. same-Spec + and -;
2. Quantity * integral scalar and scalar * Quantity;
3. compile-negative Class-O cases;
4. exact boundary values, including minima and maxima;
5. @safe pure nothrow @nogc;
6. CTFE;
7. optimized code generation versus explicitly widened raw arithmetic.

Division remains outside this result because representability loss, not only
overflow, governs integral division semantics.
