# R15 Probe 14 — real Unit/Spec API and existing result carriers

Status: research candidate; baseline validation pending. Issue #42.

## Integration seam

This probe extends a verbatim copy of develop's quantities.conversion module in
research/r15-mixed-api/quantities/conversion.d. It adds only an appended R15
extension. CI compiles that research module in place of source/quantities/conversion.d;
all other Quantity, Spec, Unit, ExactRatio and carrier dependencies are the actual
production modules. Production files remain unchanged. The copied baseline and
appended candidate make this integration experiment reproducible without making
result factories public, weakening Quantity encapsulation or adding a second
public result carrier. The appended R15 extension is the sole candidate implementation.

The existing ConversionResult and ExactResult retain private state, safe default
states, tryValue/tryFailure access, and no value on exact-required failure. The
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

## Results

Pending DMD 2.111.0 and LDC 1.41.0 debug/release matrix.
