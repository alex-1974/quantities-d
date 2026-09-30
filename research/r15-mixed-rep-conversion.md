# R15 — Floating and mixed-Rep conversion semantics

**Issue:** #42  
**Status:** Active research  
**Base:** develop@bcdd22331b90e4aed640a395f88e5422c22de611

## Existing accepted contract

ADR 0005 and ADR 0007 already establish the semantic rules:

- conversion status is `exact | inexact | overflow | nonFinite`;
- exactness is relative to the represented source value;
- potentially lossy conversion requires explicit caller intent;
- floating-to-floating exactness is not determined by inverse round-trip;
- NaN and infinity are `nonFinite`, not overflow;
- runtime represented-source floating semantics must not silently change under
  CTFE excess precision;
- exact rational Unit scale is preserved until target representation.

R15 does not reopen those decisions.

## Production implementation gap

The current public implementation has explicit overloads for:

```text
long   -> Quantity!(Spec, long)
double -> Quantity!(Spec, double)

Quantity!(Spec, long)   -> long extraction
Quantity!(Spec, double) -> double extraction
```

There is no explicit TargetRep parameter in the current public conversion API.
The source Rep therefore also determines the output Rep.

This means true mixed-Rep conversion is not expressible as an intentional
public operation yet.

R15 must also verify whether D overload conversion currently makes additional
source types compile accidentally through the `double` overload.

## Probe 1 — surface and representation matrix

Probe 1 records:

1. which `float` / `real` calls compile against the current overload set;
2. what result type is selected if they compile;
3. which Quantity Rep extraction overloads currently exist;
4. format-inclusion facts for float/double/current real;
5. complete-domain integral-to-floating exactness facts.

This is a surface audit, not a proposed API.

## Initial classification model

R15 separates two questions that must not be conflated.

### Total representation inclusion

Every value in the source representation is exactly representable in the
target representation.

Examples expected from format properties:

- `float -> double`: total exact;
- `double -> real`: total exact only on targets whose real range/precision
  contains binary64;
- `double -> float`: not total;
- current real80-like `real -> double`: not total.

### Value-dependent exactness

The representation pair is not total, but individual source values may still
convert exactly.

Examples:

- `int -> float`;
- `long -> double`;
- `double -> float`;
- current real80-like `real -> double`.

This distinction is likely to determine whether a future mixed-Rep operation
can ever be direct or must remain checked/exact-required.

## API question deliberately left open

A likely requirement is an explicit TargetRep in the conversion request, but
R15 does not yet choose syntax such as:

```text
checkedQuantity!(Spec, Unit, TargetRep)
checkedIn!(Unit, TargetRep)
```

or an alternative policy object / helper.

The public shape will be evaluated only after the pair/status matrix and
conversion kernels are proven.


## Probe 1 result — current overload surface

Both baseline compilers show the same current construction behavior:

```text
byte   -> Quantity!(Spec, long)
ubyte  -> Quantity!(Spec, long)
short  -> Quantity!(Spec, long)
ushort -> Quantity!(Spec, long)
int    -> Quantity!(Spec, long)
uint   -> Quantity!(Spec, long)
long   -> Quantity!(Spec, long)
ulong  -> Quantity!(Spec, long)

float  -> Quantity!(Spec, double)
double -> Quantity!(Spec, double)
real   -> Quantity!(Spec, double)
```

Only `long` and `double` have explicit public construction overloads.
The additional source types are admitted by D function-argument conversions
before quantities-d sees the represented source value.

Extraction does not have the same accidental widening:

```text
Quantity!(Spec, long).checkedIn   -> available
Quantity!(Spec, float).checkedIn  -> unavailable
Quantity!(Spec, double).checkedIn -> available
Quantity!(Spec, real).checkedIn   -> unavailable
```

This demonstrates that source Rep and target Rep are not yet explicit
independent parameters in the public conversion model.

## Probe 2 result — pre-kernel source loss

The accidental overload admission is not merely an API-shape issue.

A concrete signedness witness on DMD 2.111 shows:

```text
ulong.max source:        18446744073709551615
stored signed canonical: -1
checkedQuantity status:  exact
```

The represented `ulong` source is converted to `long` before the checked
conversion kernel is called. quantities-d therefore reports exactness for the
already-corrupted argument rather than for the caller's represented source
value.

This violates the accepted ADR 0005 / ADR 0007 boundary:

> checked conversion status must describe the requested conversion of the
> represented source value; source loss must not occur before status
> classification.

The same structural problem exists for `real -> double`: on real formats wider
than binary64, overload argument conversion can narrow the represented source
before quantities-d can classify exactness, overflow, or non-finite state.

The exact runtime manifestation of a particular out-of-binary64 real value is
compiler/evaluation-context sensitive because D floating expressions may retain
excess precision. That reinforces rather than weakens the contract requirement:
the public entry point must receive the actual SourceRep explicitly instead of
depending on an implicit parameter conversion.

## Immediate consequence

R15 discovered a production bug before defining any new mixed-Rep API.

Issue #44 tracks the repair. The minimal fix is intentionally separate from the
future conversion design:

- preserve only the explicitly implemented `long` and `double` construction
  source Reps;
- reject other source Reps before D can implicitly narrow/widen them;
- do not add a TargetRep API as part of the bugfix;
- resume R15 pair/API research from that explicit-source baseline.

This repair is a prerequisite for trustworthy mixed-Rep conversion research.
