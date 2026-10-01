# R15 Probe 14 — real Unit/Spec API and existing result carriers

Status: candidate validated in debug/release on both baseline compilers; not promoted. Issues #42 and #48.

## Integration seam

This probe starts from quantities.conversion at develop
b59285885bb72e4dbc7250ea8b876017e87f3fd7, adds a result-carrier hardening
candidate and appends an R15 extension in research/r15-mixed-api/quantities/conversion.d. CI compiles that research module in place of source/quantities/conversion.d;
all other Quantity, Spec, Unit, ExactRatio and carrier dependencies are the actual
production modules. Production files remain unchanged. The copied baseline and
appended candidate make this integration experiment reproducible without making
result factories public or adding a second public result carrier. The appended R15 extension is the sole candidate implementation.

The existing public ConversionResult and ExactResult types retain safe default
states, tryValue/tryFailure access, and no value on exact-required failure.
Their private representation is hardened: presence and status share one private
ubyte enum state rather than independent fields. This makes contradictory states
unrepresentable through the supported carrier operations. Unknown raw tags have
safe accessor fallbacks; no release invariant depends on assert. The
extension can use ConversionResult's private factories because it lives in the
same module, just as production conversion does. Research scalar aggregate
results are mapped immediately into those carriers and never returned through
the candidate API. Status mapping is by enum names, not research enum ordinals.

## Candidate surface and scope

Examples of deduced-source, explicit-target UFCS calls:

```d
value.checkedQuantityAs!(Length, InternationalFoot, long)
value.exactQuantityAs!(Length, InternationalFoot, long)
value.roundedQuantityAs!(Length, InternationalFoot, long, RoundingMode.floor)
q.checkedInAs!(InternationalFoot, long)
q.exactInAs!(InternationalFoot, long)
q.roundedInAs!(InternationalFoot, long, RoundingMode.nearestTiesAway)
```

The As names and template parameter placement are research candidates, not a
frozen public API. This slice supports floating sources (float, double and
trait-qualified real) and target long only. Integral sources, other targets,
generic exact-source CTFE, generic Rep qualifiers and naming reconciliation with
the older explicit-target R15 branch remain follow-up work. Const float,
immutable double and const Quantity access are concrete consumer gates.

Construction composes Unit / Spec.CanonicalUnit. Extraction composes
Spec.CanonicalUnit / Unit. The complete exact Unit factors go into the qualified
represented-source kernel from Probes 11–13, avoiding a composed ratio narrowed
to one signed-long numerator/denominator. Neither direction computes a floating
intermediate or checks exactness using a round trip. Dimension agreement, valid
Spec/Unit, nonzero scale and signed-long exact Scale metadata are compile-time
requirements. Unsupported target/source/mode combinations are rejected.

Checked fractions have inexact status and no payload. Explicit rounding preserves
inexact status with its rounded long payload. Exact-required fractions fail with
ExactFailure.inexact; overflow and nonFinite retain their corresponding failures.
The exact-unrounded range-first candidate from Probe 12 remains in effect. It
must become an explicit mixed-Rep policy decision before production promotion.

## Validation

Six real Unit/Spec pairs cover metre, the two legally distinct feet, large
composed scales, a foot-canonical Spec, and a negative canonical scale containing
long.min. Each test supplies the same represented scalar independently to
construction and to a canonical source Quantity for extraction. The oracle
computes both exact rational directions separately. It does not assume rounded
construction can be reversed exactly.

Fixed source cases include signed zero, normal/subnormal boundaries, extrema,
NaN/infinity, ties and long boundary neighbors. A seeded corpus (0x150014) adds
12,000 random source/intent/Unit cases. Python reuses Probe 13's independent
Fraction reference and IEEE source decoders; every API pair checks both directions.

The external consumer checks result defaults at CTFE, runtime checked/exact/rounded
status and payload invariants, exact failure discrimination, source-preserving
legacy API availability, and @safe pure nothrow @nogc compilation. Consumer
checks return booleans and the runner fails explicitly, so release validation
does not disappear when assertions are disabled.

Compile-negative gates cover private state/factories/aggregate forgery, private
Quantity construction, malformed Spec/Unit, wrong dimensions, zero/floating
Scale metadata, unsupported sources/targets, invalid rounding mode and ordinary
double-source CTFE. These gates compile in both debug and release. This is a
focused API/result experiment, not a complete production release-gate run or a
performance/ABI/compiler-cost qualification.

## Carrier observation and correction

The first external negative gate failed on both compilers: private fields do
not prevent D positional struct construction. The unchanged production carrier
accepts `ConversionResult!long(true,123,ConversionStatus.overflow)` and returns a
payload with overflow status. An explicit disabled constructor alone blocks
positional calls but leaves brace initialization accepted. Those failures are
preserved at commits cfd272cabffa4494dc9bdbc6b272f37de283d66f and
760c421215fbcf0394bfd127e533adecee6e002f, CI runs 36822420383 and 36822589354.
They are OBSERVE evidence, never acceptance requirements.

The final candidate uses a private typed discriminant and disables its positional
constructor. External positional/brace construction with the old field values or
ordinary integer tags, direct private tag naming and direct field/factory access
are rejected. The new state encoding is a private layout change: consumers must
rebuild; no ABI or performance claim is made. Unsafe casts and reflection-based
representation manipulation are outside the encapsulation contract. Issue #48
tracks selective production hardening separately from mixed-Rep API promotion.

## Results

Tested code commit: `f640a98b8122bdc7bf3e10ad8e28374ee2f64bbf`.
CI: https://github.com/alex-1974/quantities-d/actions/runs/36822995328.

DMD 2.111.0 and LDC 1.41.0 each passed both debug and release builds. Each build
compared 13,620 API pairs / 27,240 directions with zero mismatches: 729 checked/
rounded exact values, 241 exact-required values, 10,798 inexact outcomes, 8,163
exact-required failures, 6,729 overflow and 580 nonFinite outcomes. Carrier,
attribute, CTFE-default and compile-negative consumer gates passed. The real
platform is real80 (64,-16381,16384); a binary64-like real platform remains
unqualified. Probes 10–13 also passed again on both compilers.

The production OBSERVE runner confirmed the contradictory carrier behavior in
both debug and release against the unchanged baseline. Next is the isolated #48
fix, then broader target Rep integration and reconciliation of the candidate
names with earlier R15 API research. No whole research branch promotion is intended.

## Isolated production fix

[PR #49](https://github.com/alex-1974/quantities-d/pull/49) selectively promotes only carrier
hardening from fresh develop b59285885bb72e4dbc7250ea8b876017e87f3fd7.
Head `962d42dcafa1b56ced98e82eca0982b1cedd7ddb` passes production CI
[36823405981](https://github.com/alex-1974/quantities-d/actions/runs/36823405981) on both baseline
compilers: 12 unit-test modules in debug/release, compile-negative tests, debug/
release external consumers and release build. The private representation and
required consumer rebuild are documented in ADR 0007 and the changelog. No mixed-
Rep API/kernel or research files are included in that PR. It remains unmerged
pending explicit user merge instruction.
