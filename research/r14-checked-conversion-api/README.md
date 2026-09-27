# R14 — Checked Conversion API

Status: active research

## Question

What is the smallest public conversion vocabulary that fully implements
ADR 0005 without weakening the CTFE/UFCS requirements accepted by ADR 0006?

## Fixed semantic constraints

R14 does not reopen the following decisions:

- `Quantity!(Spec, Rep)` stores the Spec canonical value.
- Unit scale is exact rational compile-time metadata.
- non-canonical Unit conversion is explicit;
- potentially lossy conversion has caller-visible intent;
- integral conversion never silently truncates, wraps, or rounds;
- overflow is distinct from inexactness;
- explicit rounding is caller-selected;
- CTFE and UFCS are hard requirements;
- no runtime Unit/Spec metadata is added.

## Candidate result vocabulary

The initial probe will compare a compact value/status result:

```d
enum ConversionStatus
{
    exact,
    inexact,
    overflow
}

struct ConversionResult(T)
{
    T value;
    ConversionStatus status;
}
```

against APIs that encode exact-required failure separately.

The result type must remain a plain value type and usable in CTFE and
`@safe pure nothrow @nogc` code.

## Candidate operation vocabulary

The first comparison is intentionally small.

### A — intent in operation name

```d
q.checkedIn!Metre
q.exactIn!Metre
q.roundedIn!(Metre, RoundingMode.floor)
```

Construction follows the same vocabulary through free functions usable by
UFCS:

```d
value.checkedQuantity!(Length, Kilometre)
value.exactQuantity!(Length, Kilometre)
value.roundedQuantity!(Length, Kilometre, RoundingMode.floor)
```

### B — one operation plus policy

```d
q.inUnit!(Metre, ConversionPolicy.checked)
q.inUnit!(Metre, ConversionPolicy.exact)
q.inUnit!(Metre, ConversionPolicy.rounded, RoundingMode.floor)
```

Construction mirrors the same policy form.

### C — checked primitive plus derived conveniences

One checked primitive exposes status. Exact-required and rounded operations are
thin wrappers with explicit names.

This candidate is attractive if it keeps the semantic kernel singular while
the public API remains readable.

## Evaluation gates

A candidate is promotable only if it demonstrates:

1. natural UFCS at normal call sites;
2. CTFE construction and extraction;
3. DMD 2.111 and LDC 1.41 compatibility;
4. exact/inexact/overflow distinction;
5. full signed integral range;
6. no unsafe `-long.min`;
7. cross-cancellation before checked integral multiplication;
8. all four rounding modes for positive and negative values;
9. floating-source semantics consistent with ADR 0005;
10. compile-negative invalid Unit/Spec boundaries;
11. no runtime metadata or per-value storage overhead;
12. an external-consumer call site that remains understandable without reading
    implementation internals.

## Initial bias

Candidate C is the starting hypothesis, not a decision.

A single checked semantic kernel reduces the risk that exact-required and
rounded paths drift apart. Named convenience operations can then express caller
intent without forcing users to manipulate policy enums at every call site.

Evidence, not this preference, decides R14.


## Probe 1 — API shape

Implemented candidates:

- A: named intent operations with independent implementations;
- B: one operation parameterized by a conversion-policy enum;
- C: named intent operations layered over one checked primitive.

All three probes use the same deliberately trivial semantic kernel. This first
probe tests call shape, UFCS, CTFE and compiler acceptance only; it does not yet
claim conversion-algorithm correctness.

Run:

```bash
cd research/r14-checked-conversion-api
bash scripts/run.sh
```

### Early structural observation

A and C expose essentially the same readable call sites. Their important
difference is internal: C makes checked conversion the semantic primitive and
derives exact/rounded behavior from it.

B exposes policy machinery at ordinary call sites and still needs a separate
rounding-mode argument for the rounded case. It therefore has no demonstrated
surface-area advantage yet.


## Probe 2 — exact-required result contract

Candidate C now passes the real checked integral kernel on both baseline compilers.
This exposes a semantic issue in the first sketch:

```d
q.exactIn!Unit
```

must not merely return the same `ConversionResult!T` as `checkedIn`, because
that would make exact-required intent observationally identical to checked/loss-aware
intent.

Two result contracts are therefore compared next.

### E1 — status-bearing result

```d
struct ExactResult(T)
{
    T value;
    ConversionStatus status;
}
```

Only `exact` is a successful exact-required result. `inexact` and `overflow`
remain explicit, but the presence of `value` risks callers accidentally using
a rounded/truncated placeholder.

### E2 — success-bearing exact result

```d
enum ExactFailure
{
    inexact,
    overflow
}

struct ExactResult(T)
{
    bool hasValue;
    T value;
    ExactFailure failure;
}
```

The exact-required wrapper exposes a value only on semantic success. The
implementation may internally reuse the checked kernel, but the public result
shape makes accidental use of an inexact fallback less natural.

R14 should prefer the smallest CTFE-friendly value type that preserves this
distinction without exceptions, allocation, or runtime metadata.


## Probe 3 — exact result representation

The first `ExactResult` shape proved CTFE-compatible on DMD and LDC. R14 now
compares it with a sum-type-like value object that keeps state private and only
exposes:

```d
result.hasValue
result.value
result.failure
```

The goal is not a sophisticated algebraic-data-type framework. The question is
whether a tiny dedicated result type can make invalid-state misuse less natural
than a public `bool + value + failure` aggregate while retaining:

- CTFE;
- `@safe pure nothrow @nogc`;
- trivial value semantics;
- no allocation;
- small representation.

A true overlapping union is deliberately not assumed yet. D safety rules and
destructor/postblit behavior for generic `T` would need separate evidence
before such a representation could be accepted.


## Probe 3 result — exact result representation

Both E1 and the private-state E2 shape compile and execute in CTFE on DMD 2.111
and LDC 1.41.

### Comparison

#### E1 — public `bool + value + failure`

Advantages:

- mechanically simple;
- aggregate construction is trivial;
- CTFE-friendly.

Disadvantages:

- permits contradictory states such as `hasValue == true` together with an
  arbitrary failure value;
- callers can read `value` even when the result is inexact or overflow;
- invariants depend on convention rather than the type.

#### E2 — private state with constructors/accessors

Advantages:

- the public type owns its invariant;
- success and failure construction are explicit;
- callers cannot mutate the state into contradictory combinations;
- `value` and `failure` can enforce their preconditions;
- remains CTFE-compatible and allocation-free.

Costs:

- stores both payload and failure discriminator rather than overlapping them;
- therefore not representation-minimal.

### R14 direction

Prefer E2 semantics for the public exact-required result.

R14 does **not** yet require an overlapping `union`. For quantities-d's numeric
Reps, the extra discriminator/storage is paid only by a conversion result
temporary, not by every `Quantity`. A union optimization would add D-specific
generic lifetime and `@safe` complexity without evidence that it materially
matters.

The result type should therefore optimize first for invariant safety and simple
CTFE behavior. Representation compaction remains a later evidence-driven
optimization.


## Probe 4 — floating conversion semantics

ADR 0005 defines floating exactness relative to the represented floating source value,
not to an earlier decimal spelling or physical measurement.

R14 therefore evaluates floating conversion separately from the integral kernel.

Initial contract under test:

- finite source and finite result only;
- overflow is distinct from inexact;
- exact means that applying the exact rational scale and then representing the result
  in the target floating Rep introduces no additional rounding relative to the represented
  source value;
- NaN and infinities are not silently classified as ordinary exact/inexact conversions;
- no caller-selected integer-style rounding mode is applied to floating-to-floating
  conversion.

The first probe intentionally uses binary-exact examples (powers of two) and
binary-inexact decimal-style scales to make the distinction observable.


## Probe 5 — exact floating criterion from represented binary value

The reverse-operation probe is not sufficient for production because two floating
rounding steps may accidentally reconstruct the source.

R14 therefore sharpens the semantic criterion:

> A floating-to-floating unit conversion is `exact` iff the mathematical result
> obtained from the **represented source floating value** and the exact rational
> unit scale is exactly representable in the target floating Rep.

For binary floating point this can be reasoned about from the represented value
as an integer significand times a power of two. After multiplying by an exact
rational `N / D`, all odd factors remaining in the denominator must divide the
integer significand; any remaining power-of-two denominator can be absorbed into
the binary exponent. The resulting significand must then fit the target
precision/range without discarded bits.

This criterion is stronger than reverse comparison and directly matches ADR 0005.
The first implementation probe is intentionally limited to finite positive/negative
`double` values and exact rational scales; NaN/infinity policy remains separate.


### CTFE note

The initial binary64 probe used a local union to reinterpret a `double` as
`ulong`. DMD rejects reading the overlapped field during CTFE:

```text
reinterpretation through overlapped field raw is not allowed in CTFE
```

Because CTFE is a hard quantities-d requirement, R14 does not treat runtime-only
bit reinterpretation as sufficient. The probe now decomposes finite values
arithmetically, preserving a single CTFE-capable semantic path on the baseline
compilers.
