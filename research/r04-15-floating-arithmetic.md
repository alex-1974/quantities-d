# R04.15 floating arithmetic — probe evidence

Research branch: `research/r04-15-floating-arithmetic`

Baseline compilers:

- DMD 2.111.0
- LDC 1.41.0 (DMD frontend 2.111.0)

This document records research evidence only. It does not define or promote a
production API.

## Probe 1 — native floating baseline

DMD and LDC agreed on the representative D operator result-type matrix:

- floating/floating follows `float -> double -> real`;
- mixed integral/floating produces the floating operand type for the tested
  `int`, `long`, and `ulong` combinations;
- representative floating arithmetic works at CTFE and in
  `@safe pure nothrow @nogc` code;
- tested IEEE behavior for signed zero, infinities, NaN, overflow to infinity,
  and subnormals agreed on both compilers.

Observed on the current x86-64 target:

- `float.sizeof == 4`, `float.mant_dig == 24`;
- `double.sizeof == 8`, `double.mant_dig == 53`;
- `real.sizeof == 16`, `real.mant_dig == 64`.

The `real` observation is target evidence, not a portable quantities-d
contract.

## Probe 2 — Quantity-shaped floating-only arithmetic

A minimal wrapper preserving existing semantic gates showed that same-Spec
floating addition/subtraction and scalable scalar multiplication/division can
use native D floating promotion without introducing a new numerical result
carrier.

CTFE, attributes, and the tested IEEE behavior were preserved on DMD and LDC.

## Probes 3A/3B — CTFE observation boundary

At the binary32 exact-integer boundary, CTFE comparisons behaved differently
from materialized binary32 values.

For `2^24 + 1`, compile-time comparisons retained a distinction that
disappeared after materialization. Runtime-observable binary32 storage on both
compilers was:

- `2^24     -> 0x4b800000`;
- `2^24 + 1 -> 0x4b800000`;
- `2^24 + 2 -> 0x4b800001`;
- `2^24 + 3 -> 0x4b800002`.

Therefore CTFE equality alone is not a valid oracle for representability at a
floating storage boundary. Observable stored representation or an independent
type-level proof is required.

## Probe 3C — mixed promotion precision loss

After materialization, both compilers confirmed that native mixed promotion can
lose integral information before useful arithmetic:

- `16_777_216L + 0.0f` and `16_777_217L + 0.0f` produce the same
  binary32 value;
- `2^53L + 0.0` and `(2^53 + 1)L + 0.0` produce the same binary64 value;
- the same issue occurs for scalar multiplication.

This is normal floating-point conversion behavior, not a compiler defect.

## Probe 4 — full-domain exact operand conversion trait

The tested type-level criterion is:

```d
valueBits!Integral <= Floating.mant_dig
```

where signed integral `valueBits` excludes the sign bit and unsigned
`valueBits` includes the full width.

DMD and LDC agreed on the tested matrix:

| Conversion | Full integral domain exactly representable |
| --- | --- |
| int -> float | no |
| int -> double | yes |
| uint -> double | yes |
| long -> double | no |
| long -> real | yes on this target |
| ulong -> real | yes on this target |

The `real` result follows from `real.mant_dig == 64` on this target and must
not be hard-coded as a portable property.

## Probe 5 — operand conversion vs result rounding

Probe 5 separated two different sources of inexactness.

1. **Operand-conversion loss:** an integral operand may lose information before
   arithmetic when its complete domain is not exactly representable by the
   floating result representation.
2. **Ordinary floating result rounding:** even when every operand is represented
   exactly, the mathematical result may not be representable in the floating
   result representation.

Examples confirmed on both compilers:

- every `int` is exactly representable in `double`, but an
  `int + double` operation can still round its final binary64 result;
- `long -> double` can lose information before the arithmetic operation;
- the same distinction applies to multiplication;
- a Quantity-shaped admitted `int + double` prototype preserved CTFE and
  `@safe pure nothrow @nogc`.

## Current research hypothesis

The evidence supports keeping three questions separate:

1. **semantic validity** — existing Spec relation/capability machinery;
2. **operand admission / ResultRep** — representation-level policy;
3. **floating result rounding** — ordinary native floating semantics after an
   operation has been admitted.

A candidate mixed integral/floating admission rule is to require the complete
integral Rep domain to be exactly representable in the floating ResultRep.
This is not yet a production decision.

Floating/floating native D promotion remains a strong candidate.

## Architecture audit before Probe 6

At `develop@b0ab47e7d2cacf2e081d9bd21196bb367280ecd9`:

- `arithmetic_traits.d` owns semantic result resolution;
- `arithmetic_rep.d` owns integral representation/range selection;
- `quantity.d` combines semantic and representation gates;
- direct arithmetic is explicitly integral-only today.

Probe 6 should test whether floating and mixed admission can extend the existing
representation layer without changing semantic result resolution. Its first
scope is same-Spec addition/subtraction and scalable scalar
multiplication/division. Quantity-by-Quantity floating product rescaling is
deliberately deferred to a separate probe.


## Probe 6 — representation dispatcher composition

Source SHA-256:

`c96d6fc2254463e4d267365a1c6bb74d2ad09d6feb2987fd4e5f75172212b766`

DMD 2.111 and LDC 1.41 both built and ran the dispatcher prototype
successfully.

Observed on both compilers:

- `float.mant_dig == 24`, `double.mant_dig == 53`,
  `real.mant_dig == 64`;
- `short -> float` full-domain operand conversion was admitted;
- `int -> float` was rejected;
- `int -> double` was admitted;
- `long -> double` was rejected;
- admitted Quantity-shaped `int + double`, `short + float`,
  `int * double`, and `int / double` produced the expected floating
  ResultRep;
- rejected mixed combinations failed through the dispatcher constraint;
- `bool` was deliberately excluded;
- CTFE and `@safe pure nothrow @nogc` survived the prototype;
- after exact operand admission, ordinary floating result rounding remained
  native: `2^53 + 1` rounded to `2^53` in binary64.

Representative runtime observations were identical on both compilers:

```text
Q!int + Q!double -> 2147483647.5
Q!short + Q!float -> 32767.5
Q!int * double -> 1073741823.5
Q!int / double -> 1.5
exact int conversion, rounded result: 9007199254740992 + 1 -> 9007199254740992
```

Both compiler summaries were `build=0 run=0`.

### Probe 6 conclusion

A representation dispatcher can compose the established integral machinery
with floating rules without redefining the integral contracts themselves.

The prototype supports this separation:

- integral/integral: delegate to the established integral ResultRep machinery;
- floating/floating: use native D floating promotion;
- mixed integral/floating: use the native floating result only when the full
  integral operand domain is exactly representable in that floating ResultRep;
- otherwise: no direct representation result.

This remains research evidence rather than a production API decision. In
particular, scalar division is new relative to the current direct Quantity
operators and must not be promoted merely because the prototype succeeds.

The next probe should compose this policy with the actual
`arithmetic_rep.d`, `arithmetic_traits.d`, and `quantity.d` contracts
while preserving existing integral behavior. Floating Quantity-by-Quantity
product rescaling remains out of scope for that step.


## Probe 7 — integration against the real quantities-d operator architecture

Probe 7 used a clean temporary checkout of
`research/r04-15-floating-arithmetic` at
`d0ae2b5b0bf18eec473ca9b759d0620aedb2a153`.

The temporary checkout patched the real
`source/quantities/arithmetic_rep.d` and
`source/quantities/quantity.d` while leaving the research branch itself
unchanged. The patch deliberately kept the established integral
`AddRep`, `SubRep`, and `MulRep` contracts intact and introduced a
research-stage `ArithmeticRep` dispatcher beside them.

The temporary integration changed only ordinary same-Spec addition and
subtraction plus scalar multiplication/division to use the dispatcher.
Quantity-by-Quantity multiplication remained on the existing integral
path and was intentionally left out of scope.

### Probe 7A — in-tree integration

The first test run exposed only a probe-source precedence error in

`cast(short)2.quantity!(...)`

which parsed as a cast of the resulting Quantity. After correcting this
to

`(cast(short)2).quantity!(...)`

both DMD 2.111 and LDC 1.41 passed all 10 existing unittest modules and
`git diff --check` passed.

Final temporary patched-file SHA-256 values:

- `source/quantities/arithmetic_rep.d`:
  `934ba763346865bd794961fe2e42780aa70ac372c8b511349400eca28af01821`
- `source/quantities/quantity.d`:
  `fe36ac5e89d91e14cc576554f3bff26ece4f81486f7c42c6eaa8d63b77faab70`

This demonstrated that the dispatcher model can be composed with the real
Quantity operator constraints without regressing the existing integral
test suite.

### Probe 7B — external positive and compile-negative consumers

A separate set of external consumer translation units then exercised the
public Quantity surface.

Positive consumer SHA-256:

- `positive.d`:
  `27c0fa30eb9d4b63a67a4f0377bc0baf098039246b6382e8c554c4df76028ede`

It covered:

- floating/floating same-Spec addition;
- `float + double` promotion;
- admitted `short + float`;
- admitted `int + double`;
- scalar `int * double`;
- symmetric scalar `double * int Quantity`;
- research-stage scalar `int / double`.

The positive consumer built and ran successfully with both DMD and LDC.

Six external negative consumers checked:

1. `int + float`;
2. `long + double`;
3. `long * double`;
4. `long / double`;
5. addition on a non-additive Spec;
6. scalar multiplication on a non-scalable Spec.

All six were rejected by both compilers.

The rejection sites were the intended architectural gates:

- unsafe mixed representation combinations failed because
  `ArithmeticRep!(...) == void`;
- a non-additive Spec failed through
  `AddResult!(...) == void`;
- a non-scalable Spec failed through
  `isScalableValue!Spec`.

No negative consumer failed because of an unrelated internal template or
compiler error.

The complete suite was re-run after the external consumers:

```text
DMD positive consumer:      0
LDC positive consumer:      0
DMD unexpected negatives:   0
LDC unexpected negatives:   0
DMD full suite:             0
LDC full suite:             0
```

### Probe 7 conclusion

The dispatcher hypothesis survives integration with the actual
quantities-d architecture.

The evidence supports keeping three concerns separate:

1. semantic admissibility remains in the existing semantic traits such as
   `AddResult` and `isScalableValue`;
2. integral full-range safety remains in the established
   `AddRep/SubRep/MulRep` contracts;
3. ordinary floating and admitted mixed representation selection can be
   layered through a dispatcher without weakening either of the first two.

The temporary patch is not promoted production code. In particular,
scalar division is still only a research-stage candidate, and
Quantity-by-Quantity floating product/quotient arithmetic requires a
separate probe because canonical rescaling and semantic result resolution
introduce additional contracts.


## Probe 8A — floating Quantity product/quotient with identity canonical rescale

Probe 8A extended the temporary Probe-7 integration patch only. No
production commit was created.

The experiment used the actual quantities-d semantic machinery:

- `ProductResultSpec`;
- `ProductCanonicalRescale`;
- `QuotientResultSpec`;
- `QuotientCanonicalRescale`;
- the Probe-7 research `ArithmeticRep` dispatcher.

Direct Quantity-by-Quantity floating multiplication and division were
admitted only when the corresponding canonical rescale was exactly
`1 / 1`.

The temporary `source/quantities/quantity.d` SHA-256 after the Probe-8A
patch was:

`a5d8677d087f51f950e5e19a919c9f676214cfb83b649599fc6aaa230f0d55b2`

### Product cases

The probe confirmed:

- `Quantity!(Length, double) * Quantity!(Length, double)`
  resolves through the existing `Length * Length -> Area` semantic relation
  and produces `Quantity!(Area, double)`;
- admitted mixed `int * double` Quantity products use the dispatcher;
- `int * float` remains rejected because the complete `int` domain is not
  exactly representable in `float`;
- `long * double` remains rejected for the same operand-conversion reason.

The existing direct integral product behavior remained intact.

### Quotient cases

A local semantic quotient relation resolving same-kind length Quantities to a
consumer-defined dimensionless ResultSpec confirmed:

- `double / double` Quantity quotient works under identity canonical
  rescaling;
- admitted mixed `int / double` Quantity quotient works;
- direct `int / int` Quantity quotient was deliberately not introduced;
- `long / double` remains rejected by the mixed-representation admission
  rule.

### Validation

Both baseline compilers rebuilt and passed the complete test suite:

```text
DMD=0
LDC=0
diff-check=0
10 modules passed unittests
```

### Probe 8A conclusion

Floating Quantity product and quotient semantics can reuse the existing
semantic ResultSpec machinery when canonical storage requires no additional
rescaling.

This probe does **not** justify direct floating product or quotient for a
nontrivial canonical rescale. The next question is numerical rather than
semantic: how a rational canonical rescale should be evaluated for floating
representations without introducing avoidable overflow, underflow, extra
rounding, or an unnecessary exact/checked contract.


## Probe 8B — evaluation-order hazards for nontrivial floating rescale

Source SHA-256:

`a0276cd91151473954582e9656eeab9f97c6c1353dfff9c9d65241c9feb4484d`

Probe 8B compared mathematically equivalent evaluation orders for a floating
Quantity product or quotient followed by an exact rational canonical rescale.

The probe reused `scaleBinary64()` as an exact rational scaler for one
already-represented binary64 operand, but did not introduce a new product or
quotient kernel.

Both DMD 2.111 and LDC 1.41 built and ran the probe successfully, with
identical results.

### Product observations

For

`double.max * 2 * 1/2`

the mathematical result is `double.max`, but product-first evaluation
overflowed to infinity. Scaling either operand first avoided the overflow.

For

`double.max * 0.5 * 2`

the mathematical result is again `double.max`. Product-first and scaling
the right operand succeeded, while scaling the left operand first overflowed
to infinity.

For

`minSubnormal * 2 * 1/2`

the mathematical result is the minimum subnormal. Product-first and scaling
the right operand succeeded, while scaling the tiny left operand first
underflowed to zero.

The symmetric case

`2 * minSubnormal * 1/2`

showed the opposite operand choice: scaling the right operand first
underflowed to zero, while product-first and scaling the left operand
preserved the minimum subnormal.

### Quotient observations

For

`double.max / 0.5 * 1/2`

quotient-first evaluation overflowed to infinity, while rescaling either side
in an equivalent form preserved `double.max`.

For

`double.max / 2 * 2`

quotient-first and denominator-side rescaling preserved `double.max`, while
scaling the numerator side first overflowed to infinity.

For

`minSubnormal / 0.5 * 1/2`

quotient-first and denominator-side rescaling preserved the minimum
subnormal, while scaling the numerator side first underflowed to zero.

### Probe 8B conclusion

There is no single trivial evaluation order that preserves the intended
floating result across the tested range.

In particular, none of these policies is generally sufficient:

- always compute the product or quotient first;
- always apply the rational rescale to the left/numerator operand first;
- always apply it to the right/denominator operand first.

The failure mode is not compiler-specific. DMD and LDC produced identical
results for all cases.

This means `scaleBinary64()`, while useful as a building block for exact
rational scaling of one represented binary64 value, is not by itself a
general solution for nontrivial floating Quantity product/quotient rescaling.

The next research question is whether quantities-d should:

1. implement a joint floating product/quotient rescale kernel that considers
   both represented operands and the rational canonical scale together; or
2. keep direct floating Quantity product/quotient restricted to identity
   canonical rescale and require an explicit/named operation for nontrivial
   rescale.

No production choice is made by this probe.


## Probe 8C1 — exact rational oracle and fixed-width bounds

Source SHA-256:

`e4d1221f332789b203c92af98b1d7badaf616f7c2dc32c9f85af1072c01ae7af`

Probe 8C1 used Python `Fraction` as an independent exact rational oracle.
It decomposed finite binary64 values exactly, evaluated the complete
mathematical product or quotient with the canonical rational rescale, and
rounded only once at the final binary64 boundary.

The probe also derived structural fixed-width bounds from the current
binary64 significand width and the current signed-64-bit ExactRatio scale
domain.

### Known boundary vectors

The exact oracle confirmed all Probe-8B boundary cases.

For products:

- `double.max * 2 * 1/2` rounds to `double.max`; product-first produced
  infinity.
- `double.max * 0.5 * 2` rounds to `double.max`; scaling the left operand
  first produced infinity.
- `minSubnormal * 2 * 1/2` rounds to the minimum subnormal; scaling the tiny
  left operand first produced zero.
- `2 * minSubnormal * 1/2` rounds to the minimum subnormal; scaling the tiny
  right operand first produced zero.

For quotients:

- `double.max / 0.5 * 1/2` rounds to `double.max`; quotient-first produced
  infinity.
- `double.max / 2 * 2` rounds to `double.max`; scaling the numerator side
  first produced infinity.
- `minSubnormal / 0.5 * 1/2` rounds to the minimum subnormal; scaling the
  numerator side first produced zero.

### Structural width bounds

With binary64 significands of at most 53 bits and current positive scale
magnitudes bounded by signed 64-bit `long`, the exact unnormalized rational
kernel requires at most:

```text
product numerator bits : 169
product denominator bits: 63
quotient numerator bits: 116
quotient denominator bits: 116
```

The binary exponent can be tracked separately.

This means the research problem does not require arbitrary-precision integers
under the current quantities-d contracts. A fixed-width internal kernel is
theoretically sufficient.

### Random oracle comparison

20,000 deterministic random finite binary64 pairs were tested over ratios
including:

- `1/1`
- `1/2`
- `2/1`
- `2/3`
- `3/2`
- `5/7`
- `7/5`
- `381/1250`
- `1200/3937`
- `1000/1`
- `1/1000`

Mismatch counts against the exact once-rounded oracle were:

```text
product first: 3429
scale left   : 3567
scale right  : 3610

quotient first: 3419
scale lhs     : 3615
```

The first product counterexample was not an overflow/underflow case but a
one-ULP rounding difference:

```text
oracle        bits=0x47e14a4ffe991a6d
product first bits=0x47e14a4ffe991a6e
```

Likewise, the first quotient counterexample differed by one ULP:

```text
oracle         bits=0xe528fa65126e9cbb
quotient first bits=0xe528fa65126e9cba
```

### Probe 8C1 conclusion

The nontrivial floating canonical-rescale problem is not limited to avoiding
intermediate infinity or zero. Ordinary multiple-rounding effects also cause
frequent one-ULP disagreement with the exact mathematical expression rounded
once to binary64.

The evidence therefore supports evaluating the complete represented operands
and exact rational canonical scale in a joint fixed-width kernel, followed by
one final binary64 rounding step, if quantities-d chooses to support direct
nontrivial floating product/quotient rescaling.

The current bounds suggest:

- product: an internal unsigned width of at least 169 bits for the exact
  significand numerator, with a <=63-bit denominator;
- quotient: <=116-bit numerator and <=116-bit denominator;
- binary exponent tracked separately.

Probe 8C1 does not yet choose the internal representation. Probe 8C2 should
compare implementation strategies such as a compact UInt192-style value,
composition from existing `core.int128` primitives, and aggressive exact
cross-cancellation before fixed-width multiplication.


## Probe 8C2-A1 — cross-cancel plus 128-bit coverage

Source SHA-256:

`eb8aaff7798cf28ec906c874e21346f524ffbe02894c3cbdedc049c561deba6b`

Probe 8C2-A1 isolated the fixed-width coverage question before implementing
division or final binary64 rounding.

The probe decomposed finite binary64 operands to exact significands, applied
exact cross-cancellation against the rational scale, and measured the
remaining numerator/denominator bit widths.

Both DMD 2.111 and LDC 1.41 produced identical results and passed.

### Constructed extrema

The constructed product case reached the previously proven maximum:

```text
product numerator = 169 bits
product denominator = 1 bit
```

The constructed quotient case stayed within:

```text
quotient numerator = 116 bits
quotient denominator = 54 bits
```

### Deterministic random coverage

Over 200,000 finite binary64 operand pairs and the Probe-8C scale set:

```text
product samples       : 200000
product <=128 bits    : 171676
product 129..169 bits : 28324
product max observed  : 169 bits
product <=128 coverage: 85.8380 %

quotient samples      : 200000
quotient <=128/128    : 200000
quotient max numerator: 116 bits
quotient max denom    : 116 bits
quotient 128 coverage : 100.0000 %
```

The 85.8380% product figure is specific to this deterministic research
distribution and must not be interpreted as a real-workload frequency.

### Probe 8C2-A1 conclusion

Cross-cancellation does not remove the need for a wider-than-128-bit product
path under the current quantities-d contracts.

A 128-bit-only floating product kernel would be incomplete because valid
inputs still require up to 169 exact numerator bits.

For quotient arithmetic, the exact rational structure remains fully bounded by
128 bits on both numerator and denominator sides. This supports using existing
`core.int128` machinery as the primary exact quotient representation.

For product arithmetic, a practical architecture may use:

- an optional <=128-bit fast path after cross-cancellation; and
- a complete >=169-bit fallback/reference path, such as a minimal UInt192-style
  internal value.

No performance claim is made from the observed 85.8380% coverage. The next
probe should first establish correctness of the 128-bit quotient path and the
<=128-bit product subset against the exact oracle before deciding whether a
fast-path split is worthwhile.


## Probe 8C2-A2a — exact Cent/Cent rational core

Source SHA-256:

`29ba2e13b11f37b15378957d9c923898fa40abaa87a6f1579da5282e970dbc7e`

Probe 8C2-A2a implemented the exact rational pre-rounding core in D using
`core.int128.Cent` and exact cross-cancellation. `std.bigint.BigInt` was
used only as an independent research oracle.

No Quantity API or final binary64 rounding was involved.

Both DMD 2.111 and LDC 1.41 built and ran the probe successfully with identical
results.

### Quotient core

100,000 deterministic finite binary64 quotient cases were checked.

```text
checked             : 100000
mismatches          : 0
max numerator bits  : 116
max denominator bits: 116
```

Every candidate `Cent/Cent * 2^e` rational value was mathematically identical
to the independent BigInt oracle.

This validates the structural conclusion from Probe 8C2-A1: the full current
floating quotient rational core fits within 128 bits on both sides.

### Product <=128 subset

The same probe tested the product path only when exact cross-cancellation and
fixed-width multiplication remained representable in `Cent`.

```text
checked             : 85670
skipped wide        : 14330
mismatches          : 0
max numerator bits  : 117
```

All covered product cases matched the independent BigInt oracle exactly.

The skipped cases are expected and remain the responsibility of the wider
product path established by Probe 8C2-A1.

### Probe 8C2-A2a conclusion

The exact rational stage can be represented correctly in D as:

```text
numerator   : Cent
denominator : Cent
binary exponent : int
sign        : bool
```

for:

- the complete current floating quotient domain; and
- the product subset whose cross-cancelled numerator fits 128 bits.

The next step is final binary64 quantization of this exact
`Cent/Cent * 2^e` form. That rounding step must preserve the existing
represented-source semantics already validated in `binary64_scale.d`,
including:

- round-to-nearest, ties-to-even;
- direct subnormal-lattice rounding;
- signed zero;
- the normal/subnormal boundary;
- the finite/infinity midpoint.

Only after the 128-bit quantizer is bit-identical to the independent exact
oracle should a wider UInt192 product fallback be implemented.


## Probe 8C2-A2b-Q — once-rounded binary64 quotient quantization

Probe 8C2-A2b-Q isolated the complete floating quotient path after Probe
8C2-A2a had validated the exact rational `Cent/Cent * 2^e` construction.

The independent Python oracle was corrected to preserve IEEE signed zero
explicitly. Python `Fraction` itself has no signed-zero state, so zero-result
sign is now carried from the original binary64 operand signs rather than being
lost in the rational oracle.

The D quantizer was also corrected in `normalizeRatio()`. When numerator and
denominator have equal bit lengths but `N < D`, the initial exponent estimate
is zero and must be corrected to `-1`. The original probe then attempted an
invalid negative shift on the denominator side. The corrected implementation
rebuilds the aligned numerator/denominator pair after changing the exponent.

With those two probe defects removed, both baseline compilers passed the
complete quotient-only oracle set:

```text
checked             : 11123
mismatches          : 0
max numerator bits  : 116
max denominator bits: 116
```

DMD 2.111:

```text
build=0
run=0
```

LDC 1.41:

```text
build=0
run=0
```

### Probe 8C2-A2b-Q conclusion

For the current binary64 and ExactRatio contracts, a nontrivial floating
Quantity quotient can be evaluated exactly to an internal rational form using:

```text
numerator   : Cent   (<=116 bits)
denominator : Cent   (<=116 bits)
binary exponent : int
sign        : bool
```

and then rounded once to binary64 without requiring an integer wider than 128
bits.

The tested quantizer uses:

1. exact binary64 decomposition;
2. exact cross-cancellation;
3. exact `Cent/Cent * 2^e` rational construction;
4. normalization without a wide `N << 52` intermediate;
5. bit-by-bit remainder generation of the required significand bits;
6. round-to-nearest, ties-to-even;
7. direct treatment of subnormal and signed-zero boundaries.

This establishes feasibility for a complete binary64 quotient kernel using
existing `core.int128` machinery.

The product path remains separate. Even a product whose exact rational
numerator fits 128 bits can require one additional normalization bit, and the
full current product domain still requires up to 169 bits before final
rounding. Product research should therefore proceed with a deliberately wider
internal representation rather than forcing the quotient architecture to grow
beyond its proven requirement.


## Probe 8C2-B1 — complete UInt192 product kernel

Oracle SHA-256:
`14146d2d7690ae1c2c7d247567a51d8c2b7b6f4b1032773c942cc4c2ea4d8016`

D source SHA-256:
`86ee6dd33df68ab0819b33f8b5a51d69a588110d17cb2765f2bd7bad63318d9f`

Probe 8C2-B1 implemented a deliberately minimal internal `UInt192` for the
full floating product path. Required operations were limited to construction,
comparison, subtraction, shifts, bit length, and exact 128x64-to-192
multiplication.

Both baseline compilers passed with identical results:

```text
checked             : 11284
mismatches          : 0
max numerator bits  : 169
max denominator bits: 63
```

The constructed structural maximum `(2^53 - 1)^2 * long.max` reached exactly
169 bits.

### Conclusion

The complete current binary64 product domain with nontrivial exact rational
canonical rescaling is feasible with:

```text
numerator      : UInt192 (<=169 bits used)
denominator    : ulong   (<=63 bits)
binary exponent: int
sign           : bool
```

and one final round-to-nearest/ties-to-even binary64 quantization.

Together with Probe 8C2-A2b-Q, correctness feasibility is now established for
both operations:

```text
quotient: Cent / Cent * 2^e, <=116/116 bits
product : UInt192 / ulong * 2^e, <=169/63 bits
```

The remaining choice is architectural/performance-oriented: retain separate
narrow/wide kernels, share a UInt192 quantizer, or dispatch between them.
That choice requires generated-code, runtime, code-size, and CTFE evidence.


## Probe 8D-Q — narrow Cent quotient vs shared UInt192 quantizer

Probe 8D-Q compared two semantically equivalent implementations of the
already-validated floating quotient:

1. the narrow `Cent/Cent` quotient quantizer;
2. the same exact rational value widened losslessly to
   `UInt192/UInt192` before quantization.

The benchmark used 4096 deterministic runtime-generated finite quotient inputs,
a correctness preflight, warm-up, nine timed rounds, balanced AB/BA ordering,
100 repetitions per round, and an observable checksum.

Both implementations produced the identical checksum:

`0x60bec92cdf4406b8`

### DMD 2.111 release build

```text
Cent:
  min    311459101 ns
  median 313903297 ns
  max    331038742 ns

UInt192:
  min    563386418 ns
  median 572272244 ns
  max    641479097 ns

wide/cent median ratio: 1.823085
```

The shared UInt192 quantizer was approximately 82.3% slower than the narrow
Cent quotient quantizer in this benchmark.

### LDC 1.41 release build

```text
Cent:
  min    217633448 ns
  median 218392433 ns
  max    223979379 ns

UInt192:
  min    222065798 ns
  median 223345361 ns
  max    252836352 ns

wide/cent median ratio: 1.022679
```

The shared UInt192 quantizer was approximately 2.3% slower at the median on
LDC.

### Build and binary observations

The corrected lightweight harness compiled quickly:

```text
DMD release build: 0.203 s
LDC release build: 0.298 s
```

Combined benchmark binary sizes were:

```text
DMD: text 603602 bytes, total 674810 bytes
LDC: text 373771 bytes, total 436579 bytes
```

These combined binary sizes are not attributable to one implementation and
therefore are not used as a per-kernel code-size conclusion.

### Probe 8D-Q conclusion

A single always-wide UInt192 quotient quantizer is not justified as the default
portable architecture by this evidence.

For DMD 2.111, widening the already-sufficient 116-bit quotient rational to
UInt192 carries a large runtime cost. LDC 1.41 largely optimizes that extra
width away, but the portable implementation must account for the supported
compiler matrix.

The current evidence therefore favors retaining the narrow `Cent/Cent`
quotient kernel unless later compiler-specific specialization is justified by
additional measurements.

This result also reinforces the workspace rule that source symmetry is not a
performance oracle: the apparently simpler shared-wide architecture has a
material compiler-dependent runtime cost.


## Probe 8D-P — Cent fast path plus UInt192 fallback

Probe 8D-P compared two semantically equivalent complete floating product
implementations:

1. always use the validated UInt192 product/quantization path;
2. use a conservative Cent fast path when the exact post-cancellation
   numerator bit bound is <=127, otherwise fall back to UInt192.

The <=127 threshold deliberately leaves one full headroom bit for the narrow
Cent quantizer's normalization and remainder doubling. Exact decomposition,
cross-cancellation, and exponent/sign handling were shared before the branch,
so the fallback path did not repeat semantic work.

The benchmark used 4096 deterministic runtime-generated finite product inputs,
a correctness preflight, warm-up, nine balanced AB/BA rounds, 100 repetitions
per round, and an observable checksum.

Preflight:

```text
correctness preflight: 4096 vectors
fast-path cases     : 3543
wide fallback cases : 553
fast-path coverage  : 86.4990 %
checksum            : 0x0225c87a44f6c154
```

### DMD 2.111 release build

```text
Always UInt192:
  min    742764406 ns
  median 749227723 ns
  max    789030411 ns

Cent fast-path + UInt192 fallback:
  min    320334451 ns
  median 323799045 ns
  max    330255960 ns

fast/wide median ratio: 0.432177
speedup: 56.7823 %
```

The conservative narrow fast path more than halved runtime in this workload.

### LDC 1.41 release build

```text
Always UInt192:
  min    179898137 ns
  median 181483071 ns
  max    184132963 ns

Cent fast-path + UInt192 fallback:
  min    177603854 ns
  median 178797566 ns
  max    180725615 ns

fast/wide median ratio: 0.985202
speedup: 1.4798 %
```

LDC largely optimized the always-wide cost away; the fast path remained
slightly faster at the median.

### Build observations

The lightweight benchmark compiled quickly:

```text
DMD release build: 0.196 s
LDC release build: 0.341 s
```

Combined benchmark binary sizes were:

```text
DMD: text 605541 bytes, total 676933 bytes
LDC: text 374811 bytes, total 437443 bytes
```

As with Probe 8D-Q, combined binary size is not attributed to either candidate
individually.

### Probe 8D-P conclusion

The evidence favors a two-tier portable product architecture:

```text
exact decomposition + cancellation
        |
        +-- numerator safely <=127 bits
        |       -> Cent product + Cent quantizer
        |
        +-- otherwise
                -> UInt192 product + UInt192 quantizer
```

This architecture is materially faster on DMD 2.111 and does not impose a
meaningful penalty on LDC 1.41 in the tested workload.

The result also reinforces the earlier quotient finding:

- quotient should remain on its complete narrow Cent/Cent kernel;
- product benefits from a narrow Cent fast path with a UInt192 fallback;
- a single always-wide portable kernel is not justified by the supported
  compiler matrix.

The exact production cutoff remains a separate design choice. Probe 8D-P used
<=127 bits because that threshold is trivially safe for the existing narrow
quantizer. A future refinement may classify some 128-bit product numerators as
safe without requiring the wide path, but such complexity should only be added
if measurement shows a material gain.
