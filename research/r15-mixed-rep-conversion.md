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
