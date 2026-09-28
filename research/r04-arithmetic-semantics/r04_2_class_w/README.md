# R04.2.5 — Static Class-W trait and Quantity wrapper

## Goal

Replace the BigInt research calculation from R04.2.3 with a compile-time
type-width/signedness rule suitable for a zero-runtime-cost implementation.

The probe then applies that rule to a local Quantity-shaped wrapper.

## Scope

For the current built-in integer catalogue, Class W is restricted to operand
types no wider than 32 bits.

For + and - the result needs one additional mathematical value bit.

For multiplication the complete result width is derived from the operand value
widths. The selected built-in ResultRep must contain the full mathematical
range.

64-bit participation is Class O in the currently tested matrix and is rejected
by the plain operator.

This is a research-local trait, not production API.

## Gates

- expected ResultRep identities;
- symmetry for + and *;
- same-Spec Quantity + / -;
- Quantity * scalar and scalar * Quantity;
- Class O rejected at compile time;
- @safe pure nothrow @nogc;
- CTFE;
- DMD/LDC agreement.

A later probe will compare optimized Class-W wrapper codegen with explicitly
widened raw arithmetic.
