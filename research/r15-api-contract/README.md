# R15 Probe 16 — selected API request and conversion policy

Status: research decision; adapt for selective promotion after cost qualification.
This is not a production ADR, feature freeze or API freeze.

## Request vocabulary

Retain the established intent prefixes and use `As` for an explicit TargetRep:

| Intent | Construction | Extraction |
| --- | --- | --- |
| Checked | `value.checkedQuantityAs!(Spec, Unit, TargetRep)` | `q.checkedInAs!(Unit, TargetRep)` |
| Exact-required | `value.exactQuantityAs!(Spec, Unit, TargetRep)` | `q.exactInAs!(Unit, TargetRep)` |
| Explicit integral rounding | `value.roundedQuantityAs!(Spec, Unit, TargetRep, mode)` | `q.roundedInAs!(Unit, TargetRep, mode)` |

The earlier `checkedQuantityR15` / `checkedInR15` spelling in
`research/r15-explicit-target-rep` at
`089cf2dafd197bad063ed1dd1b6031ec91937d5e` was deliberately provisional.
Its accepted structural lesson is preserved: target requested explicitly,
source deduced from the represented argument. Existing production names without
`As` retain their source-preserving meaning and call forms. No second member API,
public exact-source type, inferred Unit or automatic target selection is added.

At the supported single-instantiation call surface, the outer template list
contains only the request. Eponymous templates deduce Source and Quantity Spec
inside the call; supplying extra Source/Spec template arguments is rejected.
The historical flat Probe 15 signature admitted those extra arguments and could
convert the argument to a caller-supplied Source before classification. An isolated
OBSERVE consumer preserves that evidence; the selected surface rejects it.
Explicit consumer casts and deliberate specialization of an aliased inner
function template are user-directed source transformations, outside this tested
deduction-only call surface. This is an API contract, not a security boundary.

## Exact mathematical conversion

For represented source `s`, source scale `A/B` and target scale `C/D`, classify
the exact rational value `x = s*A*D/(B*C)`. Construction targets the Spec's
canonical Unit; extraction starts from the stored canonical Unit. These are
independent conversion requests; a rounded construction cannot be assumed to
invert exactly. Representation-pair inclusion never replaces Unit analysis.

1. Validate Spec, Unit, Dimension and nonzero exact rational metadata at compile time.
2. Reject NaN/infinity source as `nonFinite`, with no payload.
3. Test exact unrounded `x` against the inclusive target interval.
4. For an in-range value, apply the requested representability/rounding policy.

The target intervals are `[long.min, long.max]`, `[-float.max, float.max]`
and `[-double.max, double.max]`. The same range-first rule applies to every
intent, including explicit integral rounding. A value outside the interval is
overflow even if quantization/truncation could return an in-range endpoint.
This extends ADR 0007's promoted binary64 conversion rule consistently to the
research target matrix; it does not redefine arithmetic overflow semantics.

| Mathematical outcome | Checked integral | Rounded integral | Checked floating | Exact-required |
| --- | --- | --- | --- | --- |
| Exactly representable | `exact`, value | `exact`, value | `exact`, value | value |
| Not exactly representable | `inexact`, no value | `inexact`, policy value | `inexact`, nearest-even value | `inexact` failure |
| Outside target interval | `overflow`, no value | `overflow`, no value | `overflow`, no value | `overflow` failure |
| Non-finite source | `nonFinite`, no value | `nonFinite`, no value | `nonFinite`, no value | `nonFinite` failure |

For integral targets the four modes are towardZero, floor, ceiling and
nearestTiesAway. Floating targets use one final nearest-even rounding and
reject integer-style RoundingMode requests. No intermediate floating conversion
may erase a decisive bit. Finite nonzero values below the least target
subnormal remain in range: underflow to signed zero is `inexact`, not overflow.
Floating zero retains the source sign combined with the composed scale sign;
integral zero has no sign. Exactness is relative to the represented source,
not an earlier decimal spelling or physical measurement.

## Admitted slice and limits

| Source | Target long | Target float | Target double | Target real/ulong |
| --- | --- | --- | --- | --- |
| long / ulong | Deferred | Checked/exact | Checked/exact | Deferred |
| float / double | Checked/exact/rounded | Checked/exact | Checked/exact | Deferred |
| trait-qualified real | Checked/exact/rounded | Checked/exact | Checked/exact | Deferred |

This is the implemented research slice, not a promise that other pairs will be
added. `int`, bool, strings and unsupported real formats remain rejected at
these entry points. Const/immutable source and Quantity deduction and
`@safe pure nothrow @nogc` are exercised. The supported request forms work both
as UFCS and normal free-function calls. Ordinary floating-path CTFE remains
unqualified and is rejected; carrier defaults retain their separate CTFE tests.
Real source support is trait-gated; only the CI binary80 format is evidenced.

The `As` surface does not add runtime Unit metadata or change Quantity identity.
The result carrier is the hardened production baseline after #49; failures have
no readable payload. D `out` destinations reset to `.init` even on failure.

## Executable evidence

`consumer.d` runs boolean checks in debug and release (no assert-dependent
side effects). It exercises all six free-function forms alongside existing
UFCS consumers, qualifier deduction, extra-template-argument rejection, interior
positive/negative rounding ties, Unit-dependent inexactness and signed underflow.

The exact range witnesses use `a=2^62` and ratio
`((a-1)/a)/(a/(a+1)) = 1 - 2^-124`. A source `2^63` constructs
`2^63 - 2^-61`, which is above long.max but truncates to long.max. Extraction
of `-2^63` through the inverse ratio is below long.min but truncates to long.min.
Every integral rounding mode must reject both as overflow. Python Fraction
arithmetic checks the witnesses independently.

The workflow reruns Probe 15's 44,352 floating-target directions and Probe 14's
27,240 integral-target directions against this shadow module for both compilers
and both builds. Historical Probe 15's tested module remains unchanged.

## Results and continuation

Final tested code: `de8e8ad0014c0f330e3a9b02ff1f8c770931749f`.
[CI 36828111936](https://github.com/alex-1974/quantities-d/actions/runs/36828111936)
passes on DMD 2.111.0 and LDC 1.41.0. The request/contract consumer and the
44,352 floating plus 27,240 integral oracle directions pass in debug, release
and each compiler's optimized bounds-on cost profile. All comparisons have
zero mismatches. The independent Fraction witnesses pass; the historical flat
signature observation is reproduced in isolation. Earlier Probes 10–15 remain
green. Real traits are binary80 `(64, -16381, 16384)`.

[Probe 17](../r15-api-cost/README.md) records runtime and consumer build cost.
Its measured wrapper ratios reveal no need to restructure the selected request
vocabulary. Absolute kernel costs identify follow-up optimization candidates;
the results are not a release performance guarantee.

Root exports, production Ddoc,
independent consumer adoption, broader Rep admission and production promotion
remain separate work. Cost qualification precedes a final public API freeze.

## Follow-up: integral identity cost

[Probe 19](../r15-integral-identity-fast-path/README.md) specializes floating-source → long for equal normalized Unit ratios. It preserves this request contract and the Probe 18 floating target paths; its independent oracle, success/failure benchmark corpora and codegen are qualified on DMD/LDC. No new Rep pair or production promotion is included.

## Follow-up: integral Source admission

[Probe 20](../r15-integral-source-api/README.md) qualifies long/ulong → long for all six selected request forms, all rounding modes, exact Unit ratios, CTFE and runtime. It preserves the floating paths and records the resulting 5 × 3 pair matrix. Historical probes remain unchanged; promotion is selective.
