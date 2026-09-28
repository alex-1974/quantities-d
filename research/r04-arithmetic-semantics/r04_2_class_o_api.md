# R04.2.4 — Class O overflow API decision

## Context

R04.2.3 established two integral arithmetic classes:

- Class W: the complete mathematical result range fits a normal built-in widened
  Rep;
- Class O: no normal built-in Rep can represent every mathematical result.

Class O therefore requires an explicit overflow decision.

This document compares public API shapes. It does not implement production
arithmetic.

## Candidate A — direct operator returns checked result

Example shape:

```d
auto r = q1 + q2; // ArithmeticResult!(Quantity!(...))
```

### Advantages

- overflow cannot be silently ignored;
- syntax remains operator-based.

### Costs

- the operator no longer returns a Quantity;
- chained arithmetic becomes result-monadic rather than algebraic;
- generic code sees different result categories depending on Rep width;
- Class W and Class O have materially different operator types;
- ordinary expressions require error-unwrapping machinery.

### Assessment

Reject as the default M3 direction.

The type discontinuity at the 32/64-bit boundary is too surprising for an
operator whose mathematical meaning is otherwise unchanged.

## Candidate B — direct operator performs checked runtime trap/assert/exception

### Advantages

- operator continues to return Quantity.

### Costs

- trap/assert behavior is build-mode sensitive or unsuitable as API semantics;
- exceptions conflict with the desired nothrow surface;
- hidden runtime checking cost;
- failure behavior is less explicit than the conversion APIs already adopted by
  quantities-d.

### Assessment

Reject.

## Candidate C — unchecked/wrapping direct operator

### Advantages

- simplest implementation;
- maps directly to machine arithmetic.

### Costs

- violates the no-silent-loss direction established by M1/R04;
- signed/unsigned and overflow behavior would leak compiler/language details;
- release behavior can be unsuitable for a strong quantity abstraction.

### Assessment

Reject.

## Candidate D — direct operators only for statically operation-safe Class W;
named checked arithmetic for Class O

Example conceptual shape:

```d
auto c = a + b;              // only when statically result-safe
auto r = checkedAdd(a, b);   // explicit overflow-capable path
```

### Advantages

- plain operators always return plain Quantity;
- any admitted integral operator is mathematically overflow-free by construction;
- no hidden runtime check for Class W;
- Class O failure is explicit at the call site;
- named checked operations can preserve @safe, pure, nothrow, @nogc;
- checked arithmetic can be added only when consumer evidence justifies it.

### Costs

- the availability of an operator depends on Rep pair;
- generic code over arbitrary integral Rep must account for that constraint;
- users with long/ulong quantities need a named operation rather than +,-,*.

### Assessment

Preferred research direction.

The restriction is visible at compile time and preserves a strong invariant:

> If an integral quantities-d arithmetic operator compiles, overflow is
> impossible for every value representable by its operand Reps.

## Candidate E — no integral arithmetic operators at M3

### Advantages

- smallest API;
- no premature arithmetic system.

### Costs

- gives up the useful and now well-characterized Class W subset;
- basic int-backed quantities cannot use natural arithmetic despite a static
  proof that widening is safe.

### Assessment

Keep as fallback if production implementation or consumer review reveals
unexpected complexity. Current research no longer requires this conservative
fallback for Class W.

## Provisional M3 policy

### Same-Spec + and -

Admit direct integral operators only when an operation-safe built-in ResultRep
exists.

The result is:

```d
Quantity!(same Spec, operation-safe ResultRep)
```

### Quantity * integral scalar

Use the same operation-safe rule for the value Rep and scalar type.

Scalar * Quantity should be symmetric.

### Overflow-capable Class O

Do not provide unchecked direct operators.

Do not make +,-,* return a result wrapper.

Named checked arithmetic is the preferred future extension, but should be
implemented only when a concrete consumer requires Class O arithmetic.

Until then, Class O expressions should fail at compile time with a diagnostic
pointing to the absence/deferred checked operation.

### Division

Unaffected by this decision.

Integral Quantity/scalar division remains a separate R04.2 I3 problem because
representability loss can occur without overflow.

## Consequences

This policy creates a compile-time safety boundary rather than a runtime one.

It also gives a precise interpretation to widening:

- widening is not merely a promotion convenience;
- it is the proof that the complete operation result range is representable;
- if that proof cannot be made with the supported built-in Reps, the plain
  operator is unavailable.

## Required next probes

Before promotion to production:

1. implement the operation-safe ResultRep calculation as a compile-time trait
   without BigInt runtime machinery in the public path;
2. prove symmetry where mathematically applicable;
3. compile-negative test Class O combinations;
4. verify actual Quantity wrapper operators retain @safe pure nothrow @nogc;
5. verify CTFE;
6. compare optimized codegen with explicitly widened raw arithmetic;
7. audit whether real consumers require long/ulong Class O checked arithmetic.
