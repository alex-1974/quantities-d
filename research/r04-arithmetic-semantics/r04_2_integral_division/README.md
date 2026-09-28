# R04.2.11 — Integral Quantity division semantics

## Question

What should `Quantity!(Spec, IntegralRep) / integralScalar` mean?

Unlike Class-W addition, subtraction and multiplication, widening cannot make
general integral division exact:

```text
5 / 2 = 2.5
```

The problem is representability loss, not merely overflow.

Raw D integral division therefore cannot be adopted as the Quantity semantic
contract because truncation would silently discard information.

## Candidate contracts

### A — direct operator uses raw integral division

Reject.

It silently truncates and violates the existing no-silent-loss conversion
policy.

### B — direct operator returns a checked/result wrapper

Reject as the default operator direction.

It changes ordinary algebraic expression shape and makes `/` unlike the
Class-W operators, which return Quantity directly.

### C — direct operator promotes to floating Rep

Do not adopt implicitly.

Choosing a floating target is itself a representation policy. It also does not
make every mathematical quotient exactly representable.

A named API may later provide this intentionally if consumer evidence requires
it.

### D — no direct integral Quantity / integral scalar operator

Preferred baseline.

Keep `/` unavailable when both the Quantity Rep and scalar are integral.
Provide named division operations only when their loss semantics are explicit.

## Named-operation candidates

Research these separately:

- `exactDiv`: succeeds only when the mathematical quotient is integral and
  representable;
- `checkedDiv`: reports exact/inexact, division-by-zero and overflow-like
  exceptional cases without silent truncation;
- `roundedDiv`: explicit rounding mode, only if a concrete consumer requires
  integer rounding;
- explicit floating division/conversion: only through an API that names the
  target representation/loss policy.

The exact naming and result type are not decided by this document.

## Edge cases to probe

For signed/unsigned built-in integers:

1. exact division, e.g. 6 / 3;
2. inexact positive division, e.g. 5 / 2;
3. inexact negative division;
4. divisor zero;
5. `T.min / -1`;
6. signed/unsigned combinations;
7. quotient result Rep requirements;
8. CTFE;
9. @safe pure nothrow @nogc.

## Provisional invariant

> An integral Quantity division API must never silently truncate a
> non-integral mathematical quotient.

This is stronger and more useful than attempting to make raw D `/` safe by
widening.

## Relationship to R04.2 Class W

The Class-W invariant remains appropriate for addition, subtraction and
multiplication because those operations map integers to integers and can be
made universally overflow-free for selected Rep combinations.

Division is a different semantic category. It must not be forced into the same
operator policy merely for syntactic symmetry.
