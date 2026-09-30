# Architecture — Initial Constraints

## Status

This document records the architectural boundary established at repository
creation. It intentionally does not freeze the core public API.

## Domain boundary

`quantities-d` owns reusable static quantity/unit semantics. It does not own the
reference systems that give domain-specific meaning to measurements.

```text
quantity semantics        quantities-d
unit identity/conversion  quantities-d
exact scale relationships quantities-d

CRS / datum / projection  outside
vertical reference frame  outside
raster georeferencing     outside
EPSG/WKT/PROJJSON         outside
```

## Established starting constraints

### Units are explicit semantics

A physical unit must never be inferred from the magnitude of a scalar value.
An API either defines its unit contract or carries enough type/metadata to make
that unit explicit.

### Distinct semantic layers stay distinct

Dimension, quantity specification/kind, unit, and reference-system semantics are
not interchangeable concepts.

### Static metadata is zero-storage metadata

The static core should encode unit/specification information in types/templates,
not in per-object runtime fields. A representative quantity should be capable of
having the same storage size as its representation type; this must be verified,
not assumed.

### Exact definitions remain exact

Where a unit conversion is normatively exact, preserve an exact compile-time
relationship for as long as practical. Do not replace an exact rational
relationship with an approximate decimal merely for implementation convenience.

### Loss is explicit

Conversions that can truncate, narrow, overflow, or otherwise lose information
must not silently masquerade as value-preserving conversions.

### Strong boundaries, lean kernels

Strong quantity types should protect public and subsystem boundaries. Numerical
algorithms may operate on explicitly normalized scalar representations where
that produces simpler/faster kernels without weakening the external semantic
contract.

### Static and dynamic units are separate concerns

Runtime-parsed unit metadata may later be useful for CRS/serialization systems,
but it must not burden the static numerical core.

## Promoted representation decision

ADR 0001 selects `Quantity!(Spec, Rep)` with canonical storage for the M1 static
core. Each Spec defines one canonical Unit contract; source Unit is explicit at
construction/conversion boundaries and is not part of permanent Quantity type
identity.

## Promoted static type relationship

ADR 0002 fixes the M1 relationship between static concepts:

- Spec -> Dimension + CanonicalUnit;
- Unit -> Dimension + exact rational scale;
- Quantity identity -> Spec × Rep.

A Spec is invalid when its CanonicalUnit Dimension differs from its own
Dimension. Dimension compatibility and quantity semantics therefore remain
separate compile-time axes.

## Promoted floating arithmetic slice

M3 now admits the first ordinary floating arithmetic operations without
weakening the existing semantic gates or integral range-safety contracts.

Same-Spec addition/subtraction, scalable scalar multiplication, and
Quantity-by-Quantity product/quotient with an exact identity canonical rescale
use a floating-aware representation dispatcher:

- integral/integral operations continue to use the established integral
  ResultRep selectors unchanged;
- floating/floating operations follow native D floating promotion;
- mixed integral/floating operations are admitted only when the complete
  integral operand Rep domain is exactly representable in the selected
  floating ResultRep;
- ordinary floating result rounding remains native floating semantics after
  admission;
- semantic capabilities such as closed addition and scalable values remain
  authoritative;
- Quantity products still require an explicit semantic ProductResultSpec and
  physical Dimension validation;
- Quantity quotients still require an explicit semantic QuotientResultSpec and
  physical Dimension validation;
- floating Quantity product and quotient support identity rescale
  natively and positive nontrivial canonical rescale when the admitted
  ResultRep is double;
- nontrivial binary64 product/quotient rescale evaluates the represented
  operands and exact rational scale jointly, then rounds once to binary64;
- binary64 quotient uses the proven Cent/Cent kernel;
- binary64 product uses the proven <=127-bit Cent fast path with UInt192
  fallback for wider exact numerators;
- represented-source nontrivial binary64 rescale is deliberately runtime-only;
- integral/integral direct quotient remains unavailable and keeps the named
  exactDiv contract.

This promoted slice does not yet establish scalar division or generalized
nontrivial exact-rescale support for float/real.

## Open design decisions

The following remain research questions and must not be treated as established
API:

- final public names/helpers for the accepted structural declaration and validation machinery;
- mixed-unit arithmetic;
- general cross-Spec arithmetic beyond explicitly declared semantic relations;
- dimensionless Quantity result semantics;
- scalar-division and nontrivial float/real rescale policy;
- affine quantity-point support;
- angle integration;
- dynamic-unit representation.

Decisions with durable API/representation consequences should be recorded in
`docs/adr/` before stabilization.

## Promoted derived-dimension and product model

M3 now provides an open canonical dimension algebra over nominal consumer-defined
dimension tags and exact derived-unit scale algebra. Dimension multiplication,
division, and integer powers are structural physical operations; they do not by
themselves invent quantity semantics.

Quantity product resolution therefore keeps four concerns separate:

- Spec algebra selects an explicitly declared semantic result;
- Dimension algebra validates the physical result dimension;
- Unit/scale algebra determines the exact mathematical product scale relative
  to the result Spec's CanonicalUnit;
- Rep algebra determines whether the numeric operation is total for the
  complete operand representation ranges.

`Area` / `SquareMetre` is the first production derived-dimension case.
Operand Specs may declare `ProductWith` / `ProductFromLeft` relations.
Consumers that own neither operand may instead supply an explicit relation set
to `product!Relations` or `exactMul!Relations`; an explicit relation set is
authoritative and does not silently fall back to operand-owned hooks.

For direct integral product operations, compilation itself is the total-safety
gate: every value representable by the operand Reps must be computable without
overflow or canonical-unit truncation. Nontrivial exact canonical rescaling is
handled by the named `exactMul` path when its compile-time range proof admits
the operation.



## Promoted integral arithmetic range classes

ADR 0008 classifies semantically valid integral arithmetic by representation
availability.

Class W operations have a built-in ResultRep that contains the complete
mathematical result range for all representable operand values. Direct
operators remain restricted to this total domain.

Class O64 operations have no built-in Rep covering the complete operand-domain
range but do have a meaningful built-in 64-bit result domain for individual
values. They may be exposed through named checked operations that distinguish
value from overflow without weakening direct-operator safety.

Class OM operations have no semantically neutral built-in 64-bit result domain
and remain unavailable until quantities-d deliberately adopts a wider public
integer representation.

Checked arithmetic does not bypass semantic Spec/Dimension/Unit validation.
Exact canonical rescaling classifies the final mathematical result: denominator
factors are cancelled before multiplication, zero multiplicative factors are
handled before unnecessary arithmetic, and compile-time ratio identities are
expressed structurally rather than left for the optimizer to rediscover.

The public names for the Class-O64 operations are intentionally not yet frozen.

## Promoted exact integral quotient model

Integral Quantity/Quantity division follows the same separation of concerns as
the promoted product model, but it is exposed as named `exactDiv` rather than
unchecked direct `/` because ordinary integral divisor representations include
zero and exactness depends on runtime values.

Operand Specs may declare `QuotientWith` / `QuotientFromLeft` semantic
relations. Consumers that own neither operand may supply an explicit ordered
`Relations.Quotient!(Lhs, Rhs)` relation to `exactDiv!Relations`; the
explicit provider is authoritative and does not fall back to operand-owned
hooks.

The physical quotient Dimension is validated independently from semantic Spec
selection. Exact Unit algebra determines the mathematical quotient unit and its
canonical-storage rescale. Positive and negative exact-result endpoints are
then proven against built-in integral representation ranges at compile time.
Unsupported Rep/scale combinations are not admitted.

Runtime evaluation detects a zero divisor, fully cross-cancels the rational
factors, and distinguishes only `exact`, `inexact`, and
`divisionByZero`. No runtime range-failure state is required for admitted
calls.

`Dimensionless` remains a physical Dimension rather than an automatically
selected semantic Spec. A dimensionless quotient is representable when an
explicit semantic ResultSpec declares that Dimension; no generic ratio Spec or
raw-scalar conversion is implied.



## Promoted declaration and validation mechanism

ADR 0003 selects ordinary user-defined D types with structural compile-time
validation. Valid Specs and Units satisfy required members and relationships;
public API boundaries provide explicit `static assert` diagnostics for invalid
declarations. No inheritance, runtime registration or declaration macro is
required for the M1 static core.


## Promoted exact-scale vocabulary

ADR 0004 exposes `ExactRatio!(Numerator, Denominator)` as the static public
vocabulary used by Unit declarations. Ratios normalize at compile time, retain
normatively exact relationships, and support the full signed `long` numerator
range. Ratio arithmetic implementation details remain internal to the M1 core.


## Promoted conversion semantics

ADR 0005 separates conversion outcome from caller intent. Conversion status
distinguishes exact, inexact and overflow; exact is relative to the represented
source value. Potentially lossy integral conversion never rounds implicitly.
Rounding is explicit caller policy and remains separate from Unit identity.


## Promoted construction API shape

ADR 0006 selects Unit-explicit free-function construction with natural UFCS:

```d
quantity!(Spec, Unit)(value)
value.quantity!(Spec, Unit)
```

Rep is inferred from the value. CTFE and UFCS are required properties of the
static core. Raw external Quantity construction and direct canonical-payload
access are intentionally blocked by module visibility.
