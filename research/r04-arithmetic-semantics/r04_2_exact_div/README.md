# R04.2.14 — Quantity-shaped exact integral division

## Goal

Validate the R04.2.12 result semantics and R04.2.13 quotient ResultRep in a
Quantity-shaped prototype.

## Contract

`exactDiv(q, scalar)` has four states:

- exact: payload contains the exact integral quotient Quantity;
- inexact: non-zero divisor leaves a remainder;
- divisionByZero: divisor is zero;
- overflow: reserved for exact quotients not representable by the selected
  result policy.

For operand pairs with a non-void R04.2.13 ResultRep, the type-level range proof
means an exact quotient cannot overflow. The overflow state remains relevant
only if a future API admits Class-O pairs through a narrower/runtime-selected
representation.

This probe therefore tests the simpler Class-W exact-division path first.

## Required properties

- no raw integral Quantity `/` operator;
- no payload for inexact or divisionByZero;
- exact signed/unsigned semantics;
- int.min / -1 succeeds through widening;
- Class-O type pairs are compile-time rejected by this prototype;
- CTFE;
- @safe pure nothrow @nogc.
