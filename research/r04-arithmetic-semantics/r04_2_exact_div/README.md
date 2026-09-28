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


## Observed result

The complete prototype gate passed in all four baseline configurations:

- DMD 2.111 debug: pass;
- DMD 2.111 release: pass;
- LDC 1.41 debug: pass;
- LDC 1.41 release: pass.

All runs exited with status 0.

The passing gate covers:

- exact quotient payload;
- inexact quotient with no payload;
- division by zero with no payload;
- int.min / -1 through widened ResultRep;
- signed/unsigned division;
- compile-time rejection of tested Class-O quotient pairs;
- absence of raw integral Quantity / scalar;
- CTFE;
- @safe pure nothrow @nogc.

## Status refinement

For the currently admitted prototype domain, `overflow` is unreachable.

R04.2.13 proves that every exact quotient for a non-void QuotientRep fits that
Rep. Class-O operand pairs are rejected at compile time. Therefore a successful
runtime classification needs only:

- exact;
- inexact;
- divisionByZero.

Do not carry an unreachable overflow state into an initial Class-W-only public
exact-division API.

If a future API admits Class-O division with a runtime-selected/narrower target
Rep, overflow can be introduced there as an observable state.

## R04.2 I3 conclusion

The preferred integral Quantity/scalar division contract is now:

1. no direct integral `/` operator;
2. named exact division;
3. statically select a quotient Rep that contains every exact quotient;
4. reject operand type pairs for which no built-in universal quotient Rep
   exists;
5. at runtime classify only exact, inexact, and divisionByZero;
6. exact carries a Quantity payload; failure states do not;
7. preserve CTFE and @safe pure nothrow @nogc.

Rounded integer division and explicitly floating division remain separate,
consumer-driven APIs rather than implicit behavior of `/`.
