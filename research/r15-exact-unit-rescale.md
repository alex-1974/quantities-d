# R15 — Exact Unit-scale mixed-Rep conversion

Issue: #42
Base: develop@b59285885bb72e4dbc7250ea8b876017e87f3fd7
Status: active research; Probe 10 validation pending

The production baseline includes the mathematical range repair from PR #47.
The earlier research/r15-explicit-target-rep branch remains retained as evidence.
Probes 5–7 there established identity conversion and the direct-rounding witness.
Probes 8/9 observed the range defect now fixed in production; they were not
acceptance gates for the new kernel.

## Scope and carrier proof

Probe 10 evaluates one finite represented source multiplied by a signed-long
numerator and a positive signed-long denominator, then quantized directly to
binary32 or binary64. Source Reps are long, ulong, float, double, and qualified
binary64-like / real80-like real. Source type is deduced from the argument.

A source significand/magnitude uses at most 64 bits. The scale numerator's
magnitude is at most 2^63, including long.min; their product uses at most
127 bits. The denominator uses at most 63 bits. Cancellation only reduces
these widths. Existing binary32 U128 normalization/bit-division machinery
is adapted in research, with target-format constants and exact remainder
classification. Production source and the public API are unchanged.

The exact mathematical finite range is checked before rounding. In-range
values use one nearest-even rounding directly on the target lattice, including
subnormals. Non-finite source values use nonFinite. Signed zero is transported.
This preserves ADR 0005/0007 and avoids the double-rounding witness from Probe 7.

## Limits

The proof concerns one already-representable signed-long scale fraction.
It does not prove that arbitrary FromUnit.Scale / ToUnit.Scale composition
fits that fraction or that 128 bits suffice after unrestricted composition.
General ratio composition, floating-to-integral conversion, real targets,
result carrier/API shape, CTFE admission, unsupported real-format qualification,
and performance/compile-time qualification remain later slices.

## Validation

The deterministic Python Fraction oracle uses seed 0x150010. It reconstructs
stored binary32/binary64 source bits and qualified real significand/exponent
tuples, checks the exact mathematical range, and computes nearest-even target
bits using integer divmod. It compares both status and payload when meaningful.

The corpus includes fixed boundaries, positive/negative zero, non-finite float
and double sources, normal/subnormal transitions, integral extrema, long.min
scale, near-unit ratios, and the direct-rounding counterexample, plus 20,000
randomized cases. Runtime pure/nothrow/safe/nogc callability is compiled and
exercised. Target-format source materialization is explicit.

Run:

```sh
dmd -Iresearch/r15-exact-unit-rescale research/r15-exact-unit-rescale/runner.d research/r15-exact-unit-rescale/kernel.d -of=/tmp/r15-probe-10
python3 research/r15-exact-unit-rescale/oracle.py /tmp/r15-probe-10
```

The dedicated workflow runs both DMD 2.111.0 and LDC 1.41.0.
No performance or production-readiness claim follows from this probe.
