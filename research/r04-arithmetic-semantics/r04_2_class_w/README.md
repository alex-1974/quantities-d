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


## Observed baseline result

The static Class-W wrapper probe passed unchanged on:

- DMD 2.111 x86_64 debug;
- DMD 2.111 x86_64 release;
- LDC 1.41 x86_64 debug;
- LDC 1.41 x86_64 release.

All compile-time gates passed, including:

- int/uint addition -> Quantity!(Length,long);
- uint/uint multiplication -> Quantity!(Length,ulong);
- symmetric scalar multiplication;
- rejection of tested 64-bit Class-O expressions;
- CTFE;
- @safe pure nothrow @nogc.

This confirms that Class-W admission can be expressed entirely at compile time
without BigInt or runtime checking.

## Remaining trait-validation gate

The current bit-width formulation is a candidate implementation, not yet the
final trait.

It must still be compared against the exact mathematical ranges from R04.2.3
for every relevant <=32-bit pair and operation.

The final production trait must be:

- safe for all operand values;
- symmetric where the operation is symmetric;
- no wider than necessary unless a deliberate canonical widening policy says
  otherwise;
- correct for unsigned subtraction, whose mathematical range can become signed;
- correct for mixed signed/unsigned multiplication;
- independent of D's native promotion quirks.

Only after this exhaustive type-matrix comparison should the trait be promoted
toward production and code-generation testing.
