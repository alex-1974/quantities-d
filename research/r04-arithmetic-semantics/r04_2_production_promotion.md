# R04.2 — Integral arithmetic production-promotion decision

## Purpose

Translate the completed R04.2 evidence into a minimal M3 production boundary.

Research success does not automatically imply public API promotion. Production
code should include only semantics that are both proven and required by the M3
model.

## Evidence now established

### Result representation for +, -, *

For every ordered pair of built-in integral Reps, operation-specific type-only
traits can select the smallest built-in Rep containing the complete
mathematical result range, or `void` when no built-in Rep is universally
sufficient.

The final traits matched an independent BigInt oracle for all:

- 8 x 8 ordered Rep pairs;
- addition;
- subtraction;
- multiplication;

for 192/192 cases on both DMD 2.111 and LDC 1.41.

### Class-W operator invariant

For admitted integral +, -, * operations:

> If the operator compiles, overflow is impossible for every value
> representable by the operand Reps.

Tested Quantity-shaped wrappers preserve:

- boundary values;
- signed/unsigned semantics;
- CTFE;
- @safe;
- pure;
- nothrow;
- @nogc.

Optimized inlineable x86_64 code was instruction-identical to explicitly
widened raw arithmetic on both baseline compilers.

DMD 2.111 can retain extra stack traffic when a one-field Quantity struct is
forced through a noinline extern(C) ABI boundary; this is not a hot-path
arithmetic semantic difference.

### Integral scalar division

Raw integral division is unsuitable because it silently truncates toward zero.

A direct integral Quantity/scalar `/` operator is therefore rejected.

For named exact division, a type-only QuotientRep rule matched an independent
BigInt range oracle for all 64 ordered built-in integral Rep pairs on both
baseline compilers.

For admitted QuotientRep pairs:

> Every exact mathematical quotient fits the selected result Rep.

The Quantity-shaped prototype passed DMD/LDC debug/release, including
int.min/-1, signed/unsigned cases, CTFE, attributes and compile-time rejection
of tested unsupported pairs.

## Promote to production infrastructure

The following mechanisms are sufficiently evidenced for production-quality
implementation:

1. internal operation-specific integral ResultRep traits for addition,
   subtraction and multiplication;
2. internal exact-quotient ResultRep trait;
3. tests proving the range rules against representative boundaries;
4. compile-negative tests for unsupported Rep combinations;
5. preservation of CTFE and @safe pure nothrow @nogc.

The production traits should not depend on BigInt. BigInt remains a research
oracle only.

## Public operators: gated by Spec semantics

### Same-Spec addition

Strong promotion candidate.

For value-like Specs where addition is semantically closed:

```text
Quantity!(Spec,A) + Quantity!(Spec,B)
    -> Quantity!(Spec, AddRep!(A,B))
```

only when AddRep is non-void.

However, R04 still owns the question of which Specs are additive. Do not assume
that dimensional equality alone grants addition.

### Same-Spec subtraction

Representation semantics are proven, but public promotion remains gated by the
Spec model.

Future affine-like quantities may require subtraction to return a different
Spec. Therefore subtraction must not be generalized solely from equal
dimensions.

### Integral scalar multiplication

Strong promotion candidate for value-like quantities:

```text
Quantity!(Spec,A) * S
S * Quantity!(Spec,A)
    -> Quantity!(Spec, MulRep!(A,S))
```

when MulRep is non-void.

This preserves the Spec and has no unit-conversion ambiguity because storage is
already canonical.

### Integral scalar division

Do not expose direct `/`.

A named exact-division operation is a production candidate:

```text
q.exactDiv(scalar)
```

for non-void QuotientRep.

The minimal observable states are:

- exact + payload;
- inexact, no payload;
- divisionByZero, no payload.

Overflow is unreachable for the admitted Class-W quotient domain and should
not be present merely for symmetry.

Exact public naming/result-type details should be finalized together with the
rest of the M3 arithmetic API.

## Do not promote yet

The following remain outside this production step:

- cross-Spec addition/subtraction;
- Quantity x Quantity;
- Quantity / Quantity;
- Area or other derived Specs;
- dimensionless result semantics;
- general checked arithmetic for Class-O +, -, *;
- rounded integral division;
- implicit integral-to-floating division;
- broad ArithmeticStatus hierarchy;
- abs, sqrt and hypot without consumer evidence.

## Recommended M3 implementation order

1. move the proven integral ResultRep machinery into an internal production
   module with focused unit tests;
2. settle the R04/R05 Spec closure rules for same-Spec + and -;
3. promote only the operators justified by those Spec rules;
4. add integral scalar multiplication where Spec preservation is valid;
5. finalize and promote exact integral scalar division as a named API;
6. run compile-negative, external-consumer and optimized-codegen gates;
7. only then begin Quantity x Quantity / derived-dimension research.

## Promotion principle

Representation safety and semantic validity are separate gates.

A mathematically safe ResultRep does not authorize an operation between Specs.
Conversely, a semantically meaningful operation is not public until its Rep
and loss behavior are proven.
