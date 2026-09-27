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


## Probe 6 — floating precision and exponent range

The represented-binary criterion now also checks whether the exact rational
result fits binary64's finite representation:

- remaining odd significand content must fit 53 significant bits;
- powers of two are moved into the exponent instead of consuming precision;
- top exponent must remain within the finite normal range;
- the normalized exponent must not fall below the subnormal quantum.

Boundary probes include an exactly representable power of two, a 54-bit odd
integer that cannot be represented exactly, `double.max`, and overflow from
scaling `double.max` by two.


### Precision-gate correction

The earlier probe expectation that represented binary64 `0.1 * 10` could be
classified as exact was wrong once target precision is included.

Ordinary IEEE-754 arithmetic produces `1.0`, but the exact mathematical product
of the represented source binary64 value and the exact integer scale 10 is not
itself exactly representable as binary64. The operation therefore rounds and must
be classified `inexact` under ADR 0005.

This is a useful counterexample to reverse-operation or round-trip exactness tests.


## Probe 7 — negative and subnormal coverage

The binary64 exactness probe now includes:

- negative exact and inexact conversions;
- the smallest positive subnormal;
- exact scaling of that subnormal by two;
- underflow below the subnormal quantum;
- the corresponding negative subnormal case.

This gate specifically checks that the arithmetic CTFE decomposition remains valid
at the lower edge of binary64 rather than only for ordinary normalized values.


## Candidate C — floating integration

The represented-binary exactness criterion is now wired into Candidate C for
`double` construction and extraction.

The public semantic split remains the same as for integral Reps:

- `checked...` returns a value plus `exact / inexact / overflow`;
- `exact...` returns `ExactResult` and exposes no usable value on failure.

Integer-style caller-selected rounding is deliberately not added to
floating-to-floating conversion. Floating conversion already follows the target
floating representation's rounding semantics; R14 tracks whether that rounding
was required rather than pretending it was an integer rounding-policy choice.

NaN and infinities remain classified outside ordinary exact/inexact finite
conversion and are currently mapped to the non-success `overflow` status in
the research kernel. Before promotion, R14 must decide whether that status name
is sufficiently precise or whether non-finite input deserves a distinct failure
category.


## Probe 8 — non-finite floating values

R14 now distinguishes non-finite floating input from arithmetic overflow.

Candidate status vocabulary under test:

```d
enum ConversionStatus
{
    exact,
    inexact,
    overflow,
    nonFinite
}
```

This keeps two materially different failures separate:

- `overflow`: a finite represented source and exact scale produce a result
  outside the target representation;
- `nonFinite`: the source is already NaN or infinity and therefore is outside
  the ordinary finite quantity-conversion contract.

`ExactFailure` mirrors the same distinction. Integral conversions never
produce `nonFinite`, but sharing the status type keeps the public checked
conversion vocabulary uniform across Reps.


# R14 consolidated result

Status: **research complete; ready for promotion to ADR / production design**.

Validated on the baseline compilers:

- DMD 2.111;
- LDC 1.41.

Final research matrix: **8 modules passed unittests on both compilers**.

## Selected API direction

Candidate C is preferred:

```d
q.checkedIn!Unit
q.exactIn!Unit
q.roundedIn!(Unit, RoundingMode.floor)

value.checkedQuantity!(Spec, Unit)
value.exactQuantity!(Spec, Unit)
value.roundedQuantity!(Spec, Unit, RoundingMode.floor)
```

The named public operations express caller intent directly while sharing common
conversion kernels internally.

## Selected result semantics

Checked/loss-aware conversion:

```d
enum ConversionStatus
{
    exact,
    inexact,
    overflow,
    nonFinite
}
```

Exact-required conversion uses an invariant-owning `ExactResult!T` with private
state rather than a public aggregate whose fields can contradict one another.

`ExactFailure` distinguishes:

- `inexact`;
- `overflow`;
- `nonFinite`.

A compact overlapping union is not required for M1 absent evidence that its added
generic lifetime / `@safe` complexity is worthwhile.

## Integral semantics

Validated requirements:

- exact rational unit scale;
- cross-cancellation before multiplication;
- full signed-long boundary including `long.min`;
- exact / inexact / overflow distinction;
- explicit caller-selected rounding;
- `towardZero`, `floor`, `ceiling`, `nearestTiesAway`;
- overflow-safe composition of source and target unit ratios;
- CTFE and UFCS.

No integral conversion silently truncates, wraps, or rounds.

## Floating semantics

Floating exactness is defined relative to the **represented source floating
value**, as required by ADR 0005.

A floating-to-floating conversion is `exact` iff applying the exact rational
unit scale to that represented value yields a mathematical result exactly
representable in the target floating Rep.

Round-trip / inverse-operation equality is explicitly rejected as an exactness
test. The `0.1 * 10 -> 1.0` counterexample demonstrates why: ordinary binary64
arithmetic returns 1.0, but the exact product of represented binary64 0.1 and 10
requires rounding and is therefore `inexact`.

The binary64 research path validates:

- normal values;
- negative values;
- subnormals;
- significand precision;
- exponent range;
- overflow;
- non-finite input;
- CTFE without runtime-only bit reinterpretation.

NaN and infinities are classified as `nonFinite`, distinct from overflow.

Integer-style `RoundingMode` is not applied to floating-to-floating conversion;
the API reports whether the target floating representation required rounding.

## CTFE finding

Union-based reinterpretation of `double` to integer bits is not valid in CTFE on
the baseline DMD compiler. R14 therefore uses an arithmetic decomposition path for
the exactness probe.

This is a design constraint for the production implementation: runtime-only
bit-cast tricks are insufficient where the public operation promises CTFE.

## Items not yet frozen by R14

R14 establishes semantics and API vocabulary, but does not yet freeze:

- final module placement;
- exact internal kernel decomposition;
- representation/layout micro-optimizations for result types;
- generalized `float` / `real` implementation details beyond the validated
  binary64 research path;
- mixed integral/floating Rep conversion policy;
- compile-time diagnostics wording;
- public documentation wording.

These remain production implementation / follow-up research concerns and must not
weaken the accepted semantics above.


## Probe 9 — binary64 value generation and CTFE/runtime rounding parity

The first production-facing floating implementation exposed a separate problem
from exactness classification:

```d
(value * cast(double) numerator) / cast(double) denominator
```

can overflow or underflow in an intermediate even when the exact rational result
is representable. A concrete regression is:

```text
double.max * 2 / 3
```

The exact mathematical result is finite, but multiplying by 2 first overflows.

R14 therefore prototypes a value-generation kernel based on `frexp` / `ldexp`
that separates the source binary exponent from the rational scale and absorbs
powers of two into the exponent before applying the remaining odd ratio.

Baseline probes confirm that `frexp` / `ldexp` are CTFE-usable on:

- DMD 2.111;
- LDC 1.41.

The prototype also avoids the known `double.max * 2 / 3` intermediate-overflow
failure on both compilers.

### Important CTFE finding

At the lower binary64 boundary, CTFE and runtime do not necessarily expose the
same rounding behavior when using ordinary floating operations alone.

For half the minimum positive binary64 subnormal, the CTFE expression can retain
a positive value below the binary64 subnormal quantum, while runtime binary64
rounds the same result to `0.0`.

Therefore:

> CTFE support of `frexp` / `ldexp` is necessary but not sufficient to prove
> CTFE/runtime binary64 semantic equivalence.

This becomes a promotion gate for the production floating kernel.

### Promotion gate

Before replacing the production floating value-generation expression, the kernel
must demonstrate:

1. no avoidable intermediate overflow or underflow for finite representable
   rational results;
2. explicit binary64 quantization/rounding semantics where CTFE would otherwise
   retain excess precision;
3. identical observable result/status semantics at CTFE and runtime for the
   tested binary64 boundary matrix;
4. DMD 2.111 and LDC 1.41 compatibility;
5. `@safe pure nothrow @nogc`;
6. preservation of the represented-source exactness classification established
   earlier in R14.

Until this gate is satisfied, the floating production slice remains blocked and
PR #9 must remain draft.
