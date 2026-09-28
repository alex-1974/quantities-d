# R04.2 — Integral arithmetic policy

## Purpose

Determine the minimum integral arithmetic surface justified for Quantity without
turning quantities-d into a general checked-integer library.

R04.1 established that raw D integer arithmetic cannot itself be the public
semantic contract.

## Operations must be decided independently

### Same-Spec addition/subtraction

Candidate use cases are strong: accumulation, differences, offsets, bounds, and
geometry-derived scalar results.

Questions:

- same Rep only or safe widening;
- overflow behavior;
- whether subtraction preserves Spec for the ordinary relative Specs admitted by
  M3;
- whether checked variants are required before operators are exposed.

### Quantity × scalar

Also strongly justified for relative quantities.

Questions:

- scalar Rep compatibility;
- signed/unsigned mixing;
- overflow;
- whether a widening result Rep is sufficient or checked multiplication is
  required.

### Quantity / scalar

This is fundamentally different for integral Rep.

Ordinary integer division can discard information. Therefore a bare integral
`Quantity / scalar` must not silently imply exact arithmetic.

Candidates:

A. reject integral division unless statically/value-provably exact;
B. return a checked/exact result;
C. require an explicit rounded division intent;
D. promote to a floating result by explicit API rather than operator magic.

### Quantity × Quantity and Quantity / Quantity

Deferred from R04.2. They additionally require derived Dimension and result-Spec
decisions and belong after the primitive Rep policy is known.

## Safe widening

A compile-time notion of safe widening may be useful, but only if it means that
**every** value of the source Rep is representable by the target Rep.

Examples to test rather than assume:

- byte -> short/int/long
- ubyte -> ushort/uint/ulong
- byte -> ushort?
- uint -> long
- int -> long
- int + uint: is long the smallest ordinary D integral type representing the
  full mathematical ranges of both operands and their operation result?

Important: representing both operands is not sufficient to represent the result
of addition or multiplication. Operation range and operand range are separate
questions.

## Overflow policy candidates

1. unchecked operators mirroring machine arithmetic — disfavored by R04.1;
2. checked operators returning a result/status type;
3. operators only for cases where overflow can be excluded by representation
   policy — likely too restrictive for same-width arithmetic;
4. no integral operators initially; expose arithmetic only once a consumer
   proves the need and required failure semantics.

Candidate 4 is a legitimate M3 outcome. The library does not need an operator
merely because dimensional analysis permits one.

## Decision gate

Integral arithmetic enters production only when each exposed operation has:

- a result-Rep rule;
- signedness rule;
- overflow semantics;
- loss/truncation semantics;
- CTFE behavior;
- DMD/LDC agreement;
- compile-negative cases;
- a consumer-backed reason to exist.


## Policy decomposition after R04.4/R04.5

Floating arithmetic now has separate semantic and code-generation evidence.
Integral arithmetic must not inherit that policy mechanically.

Treat the integral problem as four independent decisions.

### I1 — same-Spec addition and subtraction

Questions:

1. Which Rep combinations are admitted?
2. What is the result Rep?
3. How is mathematical overflow represented?
4. Does subtraction always preserve Spec, or must future affine-like Specs be
   excluded by an explicit capability?

The native D result type alone is insufficient because signed/unsigned mixing
can reinterpret negative mathematical results as large unsigned values.

### I2 — Quantity multiplied by an integral scalar

This is semantically distinct from Quantity x Quantity.

Questions:

1. Which scalar signedness combinations are admitted?
2. What is ResultRep?
3. What happens when the exact mathematical product is outside ResultRep?
4. Is scalar x Quantity exactly symmetric with Quantity x scalar?

No rounding policy is needed when the mathematical result is integral, but
overflow policy is still required.

### I3 — Quantity divided by an integral scalar

This operation introduces a new problem: representability loss without
overflow.

For example, an integral Quantity value 5 divided by scalar 2 has exact
mathematical result 2.5, which cannot be represented by an integral Rep.

Therefore raw D truncation must not silently define quantities-d semantics.

Candidate public policies:

A. no direct integral Quantity/scalar division;
B. direct division only when exact, with a checked/exact result;
C. explicit rounded division with a rounding mode;
D. explicit promotion to a floating Rep.

These policies may coexist as named APIs, but an operator must not silently
choose among them.

### I4 — Quantity x Quantity and Quantity / Quantity

Deferred from the minimum integral policy.

These operations require derived-dimension/result-Spec decisions first. Their
integer overflow/loss policy should reuse the decisions established for I1-I3
rather than inventing a second arithmetic system.

## Minimum research order

1. determine a safe ResultRep rule for I1 and I2;
2. determine overflow behavior independently of ResultRep selection;
3. test signed/unsigned and width boundaries;
4. decide whether any direct integral operator remains simple enough to justify;
5. treat I3 loss/rounding as a separate explicit API decision;
6. only then connect the result to production Quantity operators.

## Design constraint

Do not solve R04.2 by building a general checked-integer arithmetic library
inside quantities-d.

If the minimum correct operator policy becomes substantially more complex than
the user-facing value of the operators, withholding the integral operator is a
valid M3 outcome.
