# R15 — Composed Unit-scale exact conversion

Issue: #42
Status: Probe 11 validation pending
Builds on Probe 10 at develop base b592858.

## Mathematical scope

For represented source s * 2^e and two exact Unit scales A/B and C/D:

    target mathematical value = s * A * D / (B * C) * 2^e

All denominator factors are cross-cancelled against every numerator factor
before multiplication. A finite magnitude/significand uses at most 64 bits;
signed-long scale numerator magnitude is at most 2^63, and positive scale
denominators are at most 2^63-1. Thus the reduced numerator needs at most
190 bits and the denominator at most 126 bits. The binary exponent remains
separate. Signs are handled without signed absolute-value overflow.

This bound concerns two declared signed-long rational scales, not an arbitrary
number of multiplied Unit expressions or unbounded integer source Reps.

## Necessary-width witness

Source: ulong.max; exponent 0.

From scale:
9223372036854775807 / 9223372036854775789

To scale:
9223372036854775787 / 9223372036854775801

These factors are pairwise coprime and coprime to the source. The numerator
still needs 190 bits and denominator 126 bits after full reduction. The result
is inside the binary64 finite range. A blanket 128-bit carrier therefore
cannot cover all admitted two-scale mathematical conversions.

## Research implementation

A private 192-bit base-2^32 carrier evaluates the reduced rational expression.
It is not a public Quantity Rep. Limb multiplication bounds every accumulation
within ulong, checks unused high limbs, and preserves the exponent separately.

The target-range comparison, normalized remainder division and direct target
quantization from Probe 10 are adapted to the wider carrier. For the proven
190/126-bit input bound, normalization and one-bit remainder doubling fit
within 192 bits. Binary32/binary64 range classification precedes nearest-even
rounding; subnormal targets use their own fixed lattice.

Probe 11 accepts an explicit represented-source significand/exponent/sign
tuple. It validates the composed rational kernel and does not newly establish
source-type deduction, real ABI decomposition, a public construction/extraction
API, or real targets. Probe 10 separately supplies source-decomposition evidence.

## Gates

Independent Fraction oracle, seed 0x150011:

- reduced numerator/denominator bit widths as well as status and result bits;
- the 190/126-bit witness;
- complete cancellation of identical Unit scales;
- integral magnitude extrema and long.min scale factors;
- both signs and signed zero;
- mathematical overflow boundaries;
- normal/subnormal targets and direct-rounding counterexample;
- very large positive/negative separate exponents;
- 20,000 randomized tuples plus fixed cases.

The existing DMD 2.111.0 / LDC 1.41.0 research workflow runs Probe 10 and 11.
Runtime safe/pure/nothrow/nogc callability is compiled and exercised.

## Decision boundary

Pending validation, retain a private wide fallback candidate rather than
introducing public wider Reps or rejecting valid results due to intermediate
width. Whether to dispatch between the 128-bit and 192-bit candidates requires
later semantic equivalence and performance qualification.

Compile-time Unit-ratio composition, floating-to-integral conversion, real
targets, public result carrier, CTFE admission, and performance/compile-time
cost remain unqualified.
