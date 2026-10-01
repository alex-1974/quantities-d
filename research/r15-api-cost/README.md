# R15 Probe 17 — API and consumer build cost

Status: research measurement, not a release benchmark or performance guarantee.
The measured API is Probe 16's selected request surface. Production is unchanged.

## Method

Runtime compares checked/rounded **construction** with the same exact conversion
kernel called directly. Both paths classify the same represented source, compose
the same rational Unit factors, obey range-before-rounding and produce identical
status, payload presence and target bits. A native multiply/cast has different
semantics and is not used as the baseline. No C++ parity claim follows from this
experiment.

Before timing, every input is compared individually. Timed batch checksums must
match the warmed result. The non-inlined batch loop writes an observable sink,
so results are consumed and the loop is not a pure common subexpression.
Both timed paths include the same status/presence/bit normalization and checksum
cost. The reported difference is the API/carrier path relative to that normalized
kernel, not an isolated instruction count. Compiler codegen inspection is still
needed before attributing a small difference to a specific abstraction.

Each case uses 8,192 precomputed inputs and seven measured rounds after warmup,
alternating the order of API and kernel. The median, minimum, maximum and checksum
are printed. Floating corpora mix signed normal values with eight edge cases;
ulong inputs approach ulong.max; real inputs have 64-bit significands near unit
magnitude. This is a focused workload rather than the correctness oracle corpus.
Nine cases cover identity, nontrivial/direct rounding, wide composed ratios,
integral-source conversion and checked/rounded integral targets.

Primary compiler-specific optimized profiles:

| Compiler | Flags |
| --- | --- |
| DMD | `-release -O -inline -boundscheck=on` |
| LDC | `-release -O3 -boundscheck=on` |

Bounds checks remain active. LDC's native optimizer profile replaces DMD's
`-inline` switch, which LDC does not accept. The workflow
prints compiler versions, flags and host CPU details. Neither relaxed floating
math nor a bounds-off comparison is introduced.

Compiler cost is three end-to-end compile/link measurements of an import-only
executable and a consumer instantiating eight calls across all six request names,
three source Reps and three target Reps. The explicit library/kernel source lists,
flags and output style are matched. Wall seconds and peak RSS KiB come from
`/usr/bin/time`. This measures the whole consumer build, not only template
instantiation; scheduler/cache/linker effects and extra consumer code remain
part of the result. No compile-time threshold is inferred from three samples.

## Results

Tested code: `de8e8ad0014c0f330e3a9b02ff1f8c770931749f`.
[CI 36828111936](https://github.com/alex-1974/quantities-d/actions/runs/36828111936)
passes on both compilers. All 8,192 inputs in each of nine cases agree individually;
all timed checksums agree. The contract consumer and independent floating/integral
oracles also pass under the exact optimized flags used for measurement.
Both recorded hosts report AMD EPYC 7763; they are separate shared CI runners.
Compiler-to-compiler absolute timings are not controlled comparisons.

Median batch time divided by input count:

| Case | DMD API / kernel ns | Ratio | LDC API / kernel ns | Ratio |
| --- | ---: | ---: | ---: | ---: |
| double_float_identity | 1617.70 / 1580.58 | 1.023 | 416.19 / 415.83 | 1.001 |
| double_float_direct_rounding | 1723.52 / 1683.25 | 1.024 | 536.43 / 536.12 | 1.001 |
| double_double_foot | 2870.32 / 2834.09 | 1.013 | 760.03 / 760.71 | 0.999 |
| double_double_wide_composed | 3171.70 / 3146.29 | 1.008 | 981.92 / 978.45 | 1.004 |
| ulong_double_identity | 2762.06 / 2739.12 | 1.008 | 551.88 / 551.44 | 1.001 |
| float_double_identity | 2117.40 / 2072.74 | 1.022 | 461.07 / 460.03 | 1.002 |
| double_long_checked | 5976.37 / 5925.73 | 1.009 | 1818.07 / 1816.11 | 1.001 |
| double_long_floor_foot | 5386.18 / 5318.90 | 1.013 | 1749.40 / 1750.11 | 1.000 |
| real_double_wide_composed | 3427.20 / 3380.74 | 1.014 | 1179.19 / 1178.59 | 1.001 |

API/kernel median ratios range from 1.008 to 1.024 for DMD and 0.999 to 1.004
for LDC in this run. Small differences, including ratios below one, must not be
treated as stable speedups. The exact kernel dominates these normalized paths.
Raw minima/maxima and checksums are retained in [results.json](results.json).

Whole-consumer build medians (three rounds):

| Compiler | Import baseline seconds | Consumer seconds | Baseline RSS KiB | Consumer RSS KiB |
| --- | ---: | ---: | ---: | ---: |
| DMD | 0.33 | 0.35 | 82,424 | 82,644 |
| LDC | 0.94 | 1.08 | 166,312 | 171,344 |

There is no measured API-layout blocker in this small consumer. Compile cost
grows with the instantiated request set; this sample does not establish a
workspace-wide or large-application budget. Nine runtime cases are not the same
instantiation set as the eight-call build consumer.

Runtime ratios are observational; a stable regression threshold needs
repeated measurements on a controlled host. No optimization is accepted on the
basis of a single shared CI runner.

## Next qualification

The next candidates are identity/inclusion fast paths and integral floor
extraction. Inspect their generated code and repeat on the intended local target;
any faster path must retain the same status, bits, signed zero and CTFE scope. Measure extraction and exact-required paths separately
if a real consumer makes them important. A same-semantics external reference is
needed for any cross-language performance claim. Wider pair admission, CTFE,
root exports/Ddoc and independent consumer qualification remain promotion work.
