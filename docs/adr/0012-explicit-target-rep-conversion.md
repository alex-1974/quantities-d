# ADR 0012 — Explicit TargetRep conversion and R15 promotion boundary

- Status: Accepted
- Date: 2026-10-01
- Research: R15, issue #42
- Related: ADR 0004, ADR 0005, ADR 0007, ADR 0010, ADR 0011
- Decision scope: first explicit-target conversion slice; no API freeze

## Context

Unit scale and representation conversion are independent sources of loss. R15
Probes 10–20 qualified exact composed Unit conversion, direct binary32/binary64
quantization, full integral source magnitude, result contracts and specialized
identity paths. Probe 21 prepares package-root exports and an explicit CTFE
boundary. A long-lived research branch is evidence, not a production merge unit.

ADR 0011 qualifies trait-driven real arithmetic. That does not establish the
R15 conversion-to-real range, result-status, one-final-rounding and public API
contract. Target real therefore needs a separate conversion qualification.

## Decision

### 1. Explicit request surface

Retain legacy inferred-Rep operations. Add these six free-function operations,
with identical UFCS spelling, exported from both quantities.conversion and the
quantities package root:

```d
value.checkedQuantityAs!(Spec, Unit, TargetRep)
value.exactQuantityAs!(Spec, Unit, TargetRep)
value.roundedQuantityAs!(Spec, Unit, TargetRep, RoundingMode.floor)
q.checkedInAs!(Unit, TargetRep)
q.exactInAs!(Unit, TargetRep)
q.roundedInAs!(Unit, TargetRep, RoundingMode.floor)
```

Construction converts Source Unit to Spec.CanonicalUnit and returns a result
carrying Quantity!(Spec, TargetRep). Extraction converts Spec.CanonicalUnit to
requested Unit and returns a result carrying TargetRep. Source Rep is deduced;
the public outer template list contains the request, not a Source override.

### 2. Selected pair matrix

C/E means checked/exact-required; R means the four existing integral rounding
modes. const/immutable Source qualifiers are admitted through Unqual traits.

| Source | Target long | Target float | Target double |
| --- | --- | --- | --- |
| long | C/E/R | C/E | C/E |
| ulong | C/E/R | C/E | C/E |
| float | C/E/R | C/E | C/E |
| double | C/E/R | C/E | C/E |
| qualified real | C/E/R | C/E | C/E |

Target real and further integral targets, including ulong, are deferred. Source
int/bool/string and other Reps are excluded from this first request surface.
Rep/Unit/Spec validation is structural and does not infer units from magnitude.

Qualified real Source capability reuses ADR 0011 numeric trait sets: (53,-1021,
1024) or (64,-16381,16384). Unsupported real formats reject only the affected
request; other Rep requests must still compile. Current R15 native runtime
platform evidence is binary80. Trait matching or earlier arithmetic evidence
must not be described as native R15 pair qualification on a binary64-like real
platform; deployment on that platform must run the corresponding pair corpus.
No real.sizeof, ABI byte layout or padding becomes part of admission.

### 3. One exact mathematical conversion, one target quantization

Decompose the represented Source and combine both exact Unit ratios before
final quantization. Retain the full ulong domain and handle long.min without
signed absolute-value overflow. Cancel rational factors before fixed-width
multiplication. The private composed domain is bounded by 190 numerator bits
and 126 denominator bits; a private 192-bit carrier suffices. No wide Rep is
public.

Floating targets quantize directly to binary32 or binary64, nearest ties to
even. A cast through double is not an acceptable binary32 implementation when
it changes final rounding. Integral targets use explicit caller rounding only.

Classify the exact finite rational against the closed target range before any
rounding, including intervals that would round back to a valid endpoint.
Floating underflow to a signed zero is inexact with a checked payload, not
range overflow. Preserve source/scale sign for floating zero; integral zero
has no sign. NaN/Inf Source yields nonFinite without a payload; payload/sign
preservation for NaN is not promised.

### 4. Result carriers and intent

Use the existing invariant-owning ConversionResult / ExactResult, including
private typed state and release-safe construction. No aggregate/sentinel shortcut
is allowed for production.

| Outcome | Checked long target | Checked floating target | Exact-required | Rounded long target |
| --- | --- | --- | --- | --- |
| exact | exact + value | exact + value | value | exact + value |
| inexact | no value | inexact + quantized value | failure(inexact) | inexact + selected rounded value |
| overflow | no value | no value | failure(overflow) | no value |
| nonFinite | no value | no value | failure(nonFinite) | no value |

D out accessors initialize destinations to .init on entry, including failure.
Payload presence, not the scalar value, establishes success. Exactness refers
to the represented Source and requested mathematical conversion, not an earlier
measurement or decimal spelling.

### 5. CTFE and attributes

long/ulong → long requests support the same semantics at CTFE and runtime.
Every request involving an ordinary floating Source or floating TargetRep is
runtime-only and deliberately rejects CTFE before decomposition/quantization,
including real → long and total float/double identity paths. Layout-free real
decomposition does not authorize a different CTFE source contract.

The API remains @safe pure nothrow @nogc. An explicit exact floating Source CTFE
API is deferred until a concrete consumer establishes need; native legacy
canonical construction and accepted real arithmetic are not changed here.

### 6. Specialization and performance boundary

Specialize equal normalized Unit ratios only when the Source/Target domain is
proved: float→float/double, double→double, floating→long with guarded shifts,
and long/ulong→long with checked unsigned narrowing. Nonidentity factors keep
the exact composed path. Specialization may not weaken range/status/CTFE rules.

R15 measurements establish gains against the general kernel for fixed corpora,
not C++ parity or a release-wide performance guarantee. DMD carrier overhead
remains visible. The noisy DMD nonidentity quarter case requires stable-runner
qualification before production performance claims; preserve bounds checks.

## Real target decision and reopening criteria

Defer real as an explicit TargetRep in the first promotion. Never approximate it
through double or enable it merely because a trait matches ADR 0011. Reopening
requires actual-format direct quantization, signed-zero/subnormal/endpoint and
range-before-rounding tests, independent exact-rational oracle, CTFE policy,
unsupported-format gates, public carriers/consumer forms, and DMD/LDC runtime,
codegen and cost evidence. This is a bounded follow-up, not a blocker that
forces the already-qualified long/float/double target matrix to expand.

## Selective integration sequence

| Slice | Concrete change | Required acceptance evidence |
| --- | --- | --- |
| P1 private engine | Adapt composed rational and represented-source kernels into production internals; preserve trusted boundaries and validate signed Scale/full ulong domain | independent oracle corpora and production unit gates; no public wide Rep or research-module imports |
| P2 public requests | Integrate six names, package-root exports, carriers, explicit CTFE policy and proved identity specializations | all pair/status/rounding gates, root/module external consumers, compile-negative and debug/release checks on baseline DMD/LDC |
| P3 qualification/docs | Record exact optimized commands/corpora; assess stable nonidentity costs; write source Ddoc and user examples | equivalent-semantics costs with bounds on, codegen, compatibility audit and normal CI; release-only matrix remains a later gate |

Current integration state:

- P1 private engine: integrated via PR #51;
- P2 public requests: integrated via PR #52;
- equal-scale `long` / `ulong` -> `long` construction specialization: integrated via PR #55 after P3 measurement exposed material DMD carrier overhead;
- normal DMD 2.111 / LDC 1.41 CI and independent production/public-API Fraction qualification are green;
- P3 remains open in Issue #53; ADR acceptance and API freeze have not occurred.

P1 and P2 may be one implementation PR if this keeps the private engine and its
consumer validation reviewable. Start from current develop and selectively
adapt source; do not merge/cherry-pick the research shadow as a whole. Existing
source/quantities/conversion.d and source/quantities/package.d are integration
points, not replacement files. Preserve arithmetic kernels and legacy API.
Accepted production placement is left to the implementation review; avoid
copying duplicate wide/representation helpers without checking their domains.

## P3 acceptance evidence

P3 completed the production-surface qualification without expanding the selected
pair matrix or weakening semantics.

- Hosted DMD 2.111 / LDC 1.41 runtime and codegen baselines established the
  public/private cost envelope with bounds checks retained.
- LDC reduces the representative equal-scale long identity abstraction to
  effectively zero overhead.
- DMD exposed material cheap-path carrier overhead; PR #55 retained a direct
  equal-scale long/ulong -> long construction specialization, reducing the
  measured hosted public/reference identity ratio from about 4.86x to about
  1.55x in the matched P3 baseline.
- DMD 2.111, 2.112.1, and 2.113 retain final checked-carrier calls; raising the
  compiler floor is therefore not justified as a performance fix. LDC
  1.41-1.43 remains effectively zero-overhead for the identity probe.
- The full external-consumer TargetRep contract matrix compiles in about
  0.07 s on DMD 2.111 and 0.10-0.11 s on LDC 1.41 on the hosted runner, with
  modest peak-RSS and object-size cost. No API reduction is justified.
- The previously noisy DMD nonidentity quarter case was repeated on a physical
  Intel Core i7-9750H XPS runner at develop commit
  `4faa91d9c3a0c8e89eaf6351a85e1480d511d4e6`, DMD 2.111.0, 100,000
  iterations and 15 paired repeats. The paired public/private ratio had median
  1.01933, range 0.93774-1.04073, and population standard deviation 0.03110.
  The noise is bidirectional and does not establish a material systematic
  public-wrapper penalty.
- Package-root, free-function and UFCS forms, Source deduction, selected
  Source/Target pairs, result-carrier types, negative admission, and CTFE
  boundaries remain covered by external-consumer and normal CI gates.
- Native R15 qualified `real` evidence is binary80. A binary64-like native
  `real` platform remains explicitly unclaimed until its corresponding pair
  corpus is run.

These results support the selected production surface. Deferred TargetRep
families, target `real`, broader integral targets, and convenience API remain
separate future decisions rather than conditions of this ADR.

## Evidence and remaining work

- [Probe 20, selected 5×3 matrix and CTFE](https://github.com/alex-1974/quantities-d/tree/dec29519ac28b8b7389b23126e56bdcd69cbe78f/research/r15-integral-source-api)
- [Probe 20 qualified CI](https://github.com/alex-1974/quantities-d/actions/runs/36855124831): six builds, 729,888 new directional comparisons, zero mismatches; floating regressions also pass.
- [Probe 18 identity inclusion](https://github.com/alex-1974/quantities-d/tree/05cc790e5fcb0a869ef8ae02ef3597c14d1221b5/research/r15-identity-fast-path)
- [Probe 19 floating→long identity](https://github.com/alex-1974/quantities-d/tree/87ada2ff152b9972ac2f8a0fd0c8eab76bc25c6d/research/r15-integral-identity-fast-path)
- [Probe 21 qualified CI](https://github.com/alex-1974/quantities-d/actions/runs/36856511385), tested code `c4e752d9d47acb962cbd77f302198c9e0ea34551`: package-root free/UFCS forms, integral CTFE, explicit floating/real CTFE rejection and runtime contract; all retained Oracle corpora pass in six builds.
- PR #51: P1 production engine with independent Fraction qualification.
- PR #52: P2 public TargetRep requests with DMD/LDC CI, compile-negative, external-consumer, and public-API oracle qualification.
- PR #54 / Issue #53: first hosted P3 runtime/codegen baseline; LDC public identity was zero-overhead while DMD exposed material checked-carrier overhead on the cheap equal-scale `long` path.
- PR #55: retained direct final-carrier specialization reduced the DMD hosted public/reference identity ratio from about 4.86x to about 1.55x in the matched P3 baseline without changing semantics; LDC remained zero-overhead.
- PR #56: research-only compiler-evolution probe found the remaining DMD carrier calls in 2.111, 2.112.1, and 2.113; LDC 1.41-1.43 remained effectively zero-overhead. Raising the DMD floor is therefore not a justified fix.

Issue #53 records the completed P3 qualification. Issue #42 may continue to track deferred R15 expansion beyond this accepted first TargetRep slice. Target
real deferral is explicit scope, not an assertion that R15 has no remaining
work. This proposed ADR changes no production source and creates no feature or
API freeze, release tag, package release or documentation publication.
