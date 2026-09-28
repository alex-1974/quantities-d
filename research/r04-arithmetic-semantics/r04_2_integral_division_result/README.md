# R04.2.12 — Integral division result semantics

## Goal

Define the smallest coherent result model for explicit integral Quantity
division without weakening the M1 conversion contract.

The new arithmetic condition is division by zero. It must not be confused with
conversion failure.

## Existing M1 vocabulary

Conversion currently distinguishes:

- exact;
- inexact;
- overflow;
- nonFinite.

That vocabulary describes representation/conversion outcomes. Division by zero
is an arithmetic-domain error.

## Candidate A — extend ConversionStatus with divisionByZero

Reject.

Advantages:

- reuses an existing result/status family.

Disadvantages:

- makes a conversion status describe an operation that is not a conversion;
- every conversion consumer sees an impossible division-only state;
- couples future arithmetic errors to the conversion API.

This would broaden M1 semantics for convenience rather than because the domain
model requires it.

## Candidate B — introduce broad ArithmeticStatus now

Example conceptual states:

- exact;
- inexact;
- overflow;
- divisionByZero.

Defer.

This may eventually be useful for checked arithmetic, but R04.2 Class-W
addition/subtraction/multiplication deliberately avoid runtime arithmetic
status. Introducing a general arithmetic error framework now would anticipate
APIs that do not yet exist.

## Candidate C — division-specific result vocabulary

Preferred research direction.

Use a narrow division result whose states describe only integral division:

- exact: quotient exists, is integral and representable;
- inexact: mathematical quotient is non-integral;
- divisionByZero: divisor is zero;
- overflow: exact integral quotient exists mathematically but does not fit the
  chosen result Rep.

Only `exact` carries a Quantity payload for an exact-division operation.

This keeps conversion and arithmetic domains separate while leaving room to
promote common concepts later if another checked arithmetic operation creates
real duplication.

## The signed minimum case

`T.min / -1` is mathematically integral but may exceed a signed result Rep.

It is therefore not divisionByZero and not inexact. It is overflow unless the
chosen ResultRep can represent the positive quotient.

The result-Rep policy must be defined before this case can be classified for a
concrete API.

## exactDiv vs checkedDiv

Do not create two public functions merely because M1 has both exact and checked
conversion names.

For integral division, an operation that returns a Quantity only when the
quotient is exact already needs to report why no payload exists. A single
named operation can therefore expose:

```text
exact
inexact
divisionByZero
overflow
```

A second `checkedDiv` name is justified only if it has observably different
payload semantics.

## Provisional direction

Research a single `exactDiv`-style operation first:

```text
Quantity / integral scalar
    -> exact quotient Quantity       [payload]
    -> non-integral quotient         [inexact, no payload]
    -> zero divisor                  [divisionByZero, no payload]
    -> unrepresentable exact result  [overflow, no payload]
```

Do not add a direct integral `/` operator.

Do not modify ConversionStatus.

Do not introduce a broad ArithmeticStatus until another arithmetic API proves
the abstraction useful.

## Next gate

Determine the quotient ResultRep policy.

Questions:

1. Can operand type ranges select a useful built-in quotient Rep statically?
2. Does signedness require a wider result even though division reduces
   magnitude in most cases?
3. Can `T.min / -1` become Class-W through result widening?
4. Which signed/unsigned combinations have no safe built-in quotient Rep?
5. Can the rule be derived type-only and verified exhaustively against an exact
   oracle, as R04.2.7 did for +, -, *?
