# Explicit target-Rep conversion

The six `As` requests separate the represented Source from the requested target
representation. Import either `quantities` or `quantities.conversion`. Source is
deduced; the outer request list does not accept a Source override.

```d
import quantities;

// Canonical storage is long, even though the represented input is double.
auto made = 1.5.roundedQuantityAs!(Length, Metre, long, RoundingMode.floor);
Quantity!(Length,long) q;
if (made.tryValue(q))
{
    // Extraction independently chooses double as its target representation.
    auto feet = q.checkedInAs!(InternationalFoot, double);
    double value;
    if (feet.tryValue(value)) { /* value is in international feet */ }
}
```

| Intent | Construction | Extraction | Result payload |
| --- | --- | --- | --- |
| Checked | `checkedQuantityAs!(Spec,Unit,TargetRep)(value)` | `checkedInAs!(Unit,TargetRep)(q)` | `Quantity!(Spec,TargetRep)` / `TargetRep` |
| Exact required | `exactQuantityAs!(Spec,Unit,TargetRep)(value)` | `exactInAs!(Unit,TargetRep)(q)` | Same, only when exact |
| Rounded integral | `roundedQuantityAs!(Spec,Unit,long,mode)(value)` | `roundedInAs!(Unit,long,mode)(q)` | `Quantity!(Spec,long)` / `long` |

Every request also supports UFCS (`value.checkedQuantityAs!(...)`,
`q.checkedInAs!(...)`). Valid Sources are long, ulong, float, double, and
qualified real, including const/immutable Sources. Targets are long, float,
and double. Rounded requests admit only long, with towardZero, floor, ceiling,
or nearestTiesAway. Target real/ulong and Source int/bool/string are excluded.
Spec and Unit must have matching Dimensions, nonzero signed-long numerators,
and positive signed-long denominators, including the Spec's CanonicalUnit.

Convert the exact represented Source multiplied by `Unit.Scale /
Spec.CanonicalUnit.Scale` for construction, and the inverse ratio for
extraction. Cross-cancel both ratios before multiplication. Check the exact
rational against the closed target range before rounding. For example,
`ulong.max / 2` lies at `long.max + 0.5`, so even towardZero reports overflow.
Float and double targets receive one direct nearest-even quantization; a
binary64 intermediate is not used to infer binary32 exactness.

| Outcome | Checked long | Checked float/double | Exact required | Rounded long |
| --- | --- | --- | --- | --- |
| Exact | Value | Value | Value | Value |
| Inexact | No value | Quantized value | `ExactFailure.inexact` | Selected rounded value |
| Overflow | No value | No value | `ExactFailure.overflow` | No value |
| NaN/Inf Source | No value, nonFinite | No value, nonFinite | `ExactFailure.nonFinite` | No value, nonFinite |

Floating underflow to zero is inexact with a checked payload. Floating zero
retains the Source/scale sign. NaN payload/sign preservation is not promised.
Existing ConversionResult/ExactResult accessors and default states remain
unchanged. Their `out` parameters reset to `.init` on entry, including failure;
use the boolean success channel rather than inspecting the old output value.

Long/ulong Source to long Target works at CTFE through the same APIs. Every
ordinary floating Source or Target request requires runtime, including
identities and non-finite values. This explicit boundary avoids substituting
compiler CTFE arithmetic for represented-source runtime semantics.

Qualified real uses the numeric traits `(53,-1021,1024)` or
`(64,-16381,16384)`, without ABI layout assumptions. Native Linux qualification
currently covers binary80. Binary64-like real needs its own native pair corpus
before platform support is claimed. Other real formats reject the affected
request without disabling long/ulong/float/double requests.

Legacy inferred-Rep APIs retain their existing admission and behavior. The
new APIs do not widen those overloads. This is P2 of the proposed ADR 0012;
performance qualification and API/release freeze remain separate.

Review dependency: P2 is stacked on the unmerged P1 PR #51, rather than copying
its implementation into another independent change. The temporary CI base
branch entry runs the same gates for this stacked PR; after P1 merges, retarget
P2 to develop and remove that entry. ADR #50 remains proposed until reviewed.
