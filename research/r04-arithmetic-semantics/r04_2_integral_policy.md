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
