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
