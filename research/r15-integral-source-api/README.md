# R15 Probe 20 — integral sources for explicit target long

Research-only extension of the selected Probe 16 API and Probe 19 optimized dispatch. Newly admitted sources: long/ulong (including const/immutable), target long, all six checked/exact/rounded construction/extraction forms. Other unsupported Reps stay excluded. Floating paths and their runtime CTFE boundary remain unchanged.

Semantics: magnitude of long.min is extracted as -(value+1) then unsigned +1, avoiding signed overflow. Source ulong is retained in full 64 bits. Equal normalized Unit ratios specialize long identity and guarded ulong narrowing; nonidentity ratios use the unchanged exact composed kernel at binary exponent zero. Check the exact rational against long endpoints before every rounded policy; checked inexact has no payload, rounded inexact has payload, exact requires exact. Overflow carries no payload. No nonFinite state can arise from integral sources.

Integral sources are CTFE-capable through the same public request surface and carrier contract. The consumer evaluates its full checks both at CTFE and runtime with @safe pure nothrow @nogc. Includes long.min, ulong.max, negative minimum Scale, inverse extraction, ±1.5 represented as integral source plus Unit factor, all policies, free forms and UFCS, qualified sources, default out reset, wrong-target/source and outer Source-override gates. Range-first witnesses include ulong.max/2 = long.max+0.5 and composed near-endpoint ratios.

The Fraction oracle covers both directions of 12 Unit/canonical pairs, signed minima, 64 bit-position boundaries, full-width ulong, fractions, negative scales, extreme composed numerator/denominator products and seeded random values. A copied compatibility consumer changes only three old pair-rejection assertions into admission assertions; historical Probes 14–19 remain untouched. Their oracles and the Probe 16 contract run under the new shadow API in debug, release and optimized modes.

Performance uses the Probe 19 normalized harness: 8192 precomputed inputs, 7 alternating rounds, warmup, per-input equality and checksums, bounds on. New identity success and overflow corpora are separate; foot/quarter nonidentity floor requests compare against the unchanged composed kernel with equivalent observations. Full benchmark corpus/source and compiler commands are in the Probe 20 workflow step. The benchmark materializes every codegen witness address before timing, preventing elimination of a trivial function after constant-folding its sanity call. Symbol aliases are resolved by defined addresses. Codegen follows direct calls and tail jumps, checking identity paths avoid the wide kernel while the nonidentity path and generic controls retain it. No C++ parity or release claim.

## Selected pair matrix after this probe

| Source Rep | Target long | Target float | Target double |
| --- | --- | --- | --- |
| long | checked / exact / rounded; CTFE and runtime | checked / exact; runtime | checked / exact; runtime |
| ulong | checked / exact / rounded; CTFE and runtime | checked / exact; runtime | checked / exact; runtime |
| float | checked / exact / rounded; runtime | checked / exact; runtime | checked / exact; runtime |
| double | checked / exact / rounded; runtime | checked / exact; runtime | checked / exact; runtime |
| qualified real | checked / exact / rounded; runtime | checked / exact; runtime | checked / exact; runtime |

The matrix concerns the explicit TargetRep request surface in this research snapshot. It does not expand legacy unchecked constructors. Qualification accepts real trait classes binary80 `(64,-16381,16384)` and binary64-like `(53,-1021,1024)`; only binary80 is qualified by the current runtime matrix. Target real/ulong and source int/bool/string are not admitted. Exact floating-target quantization can still be value-dependent even where Unit ratios are identity; an exact Rep inclusion can still become inexact under another rational Unit factor. No floating rounding-mode request is introduced.

## Validated result and decision

**Decision: adapt.** Admit long/ulong → long through the same explicit checked/exact/rounded requests in a future selective production slice. Preserve full source magnitude, exact rational Unit rescale and range-before-rounding. Keep identity specialization. This snapshot qualifies the research implementation; it does not change develop or freeze the API.

Tested code: `dec29519ac28b8b7389b23126e56bdcd69cbe78f`. [CI run 36855124831](https://github.com/alex-1974/quantities-d/actions/runs/36855124831) passed DMD 2.111.0 and LDC 1.41.0, each in debug, release and optimized builds. Per build: **60,824 API pairs / 121,648 directional comparisons**, zero mismatches; across six builds: **729,888 new directional comparisons**. The same full consumer passes CTFE static assertion and runtime execution in every build. Floating Probes 14/15/16/18/19 also pass under the new shadow API in all six builds, including the Probe 19 367,044 directional plus 26,200 tuple comparisons per build. Ordinary represented floating CTFE stays rejected.

Both jobs advertise Intel Xeon 6973P-C on separate hosted runners. DMD optimized flags: `-release -O -inline -boundscheck=on`; LDC: `-release -O3 -boundscheck=on`. No CPU affinity/frequency controls or controlled cross-compiler comparison. Same-executable normalized medians below are ns per observation; success and overflow corpora are distinct.

| Integral request / corpus | DMD API / generic control (ns) | LDC API / generic control (ns) |
| --- | ---: | ---: |


| long → long identity, signed integers -4096..4095 | 27.14 / 2847.73 | 1.18 / 1147.24 |
| ulong → long identity, unsigned integers 0..8191 | 27.21 / 2914.27 | 1.20 / 1166.16 |
| ulong → long identity, values near ulong.max | 25.94 / 150.37 | 1.18 / 36.02 |
| ulong → long identity floor, values near ulong.max | 25.93 / 151.10 | 1.18 / 35.78 |
| long → long floor foot, signed integers | 3164.03 / 3151.14 | 1253.08 / 1251.94 |
| ulong → long floor quarter, values near ulong.max | 4382.17 / 4010.96 | 1670.81 / 1668.26 |

Identity success improves by about 105–107× on DMD and 972× on LDC against the unchanged generic kernel, on these fixed corpora. Overflow improves by about 5.8× / 30×. All **25 benchmark cases** pass per-input equality and timed checksums.

Nonidentity foot ratios are 1.004 / 1.001. DMD quarter has ratio 1.093 with broad, overlapping API/control ranges (3811.67–4471.28 / 3831.47–4528.15 ns); the earlier DMD run had 0.998 for the same mathematical corpus. Both paths invoke the same composed algorithm; the public path additionally normalizes its carrier. CI variability is a plausible explanation for the median offset, not a demonstrated cause. No cost-neutrality or stable 9.3% regression claim is made for that case; production performance qualification should repeat it under stable runner conditions. No semantic or algorithm change is justified by this one measurement.

Codegen: DMD identity wrappers contain 59–60 instruction rows, six direct calls, seven reachable functions and no wide kernel. LDC identity wrappers contain 4/8/8 rows including alignment instructions, no calls, and no wide kernel. Nonidentity foot and all generic controls retain the wide kernel. Wrapper counts are not total-path counts and are not performance thresholds. See [DMD codegen](codegen-dmd.txt), [LDC codegen](codegen-ldc.txt) and [results.json](results.json) for complete records. The final harness retains every callable address; the earlier LDC label lookup failure was resolved by retention plus address-aware disassembly, without conversion changes.

Median three-round compile/link wall seconds / peak RSS KiB:

| Compiler | Import baseline | Selected-request consumer |
| --- | ---: | ---: |
| dmd-2.111.0 | 0.23 / 82316 | 0.24 / 82720 |
| ldc-1.41.0 | 0.64 / 169372 | 0.75 / 171076 |

These reuse the Probe 17 build fixtures to keep prior consumer-cost observations comparable within this run; the main Probe 20 oracle runner separately compiles/evaluates the new integral CTFE consumer. The build-cost fixture is not a measurement of CTFE scaling for arbitrarily many integral requests.

Reproduction: the **Probe 20** step of [the research workflow](../../.github/workflows/r15-exact-unit-rescale.yml) fixes module lists, shadow import precedence, compiler flags and all runner/oracle/benchmark/codegen commands. The result-recording commit only updates documentation and retained evidence. Historical kernels and probes remain intact.

Next: consolidate the R15 promotion contract and decide the qualified-real target boundary explicitly. The selected matrix now covers long/float/double targets with all five qualified Source families, but target real and further integral targets remain excluded; open issue #42 is not closed by this probe. Selective promotion still needs normal production module/API/consumer integration rather than a wholesale merge of this research branch.

## Promotion readiness follow-up

[Probe 21](../r15-promotion-readiness/README.md) adds package-root exports and an explicit CTFE rejection before every ordinary floating request, including real→long. It keeps integral CTFE and reruns the complete pair matrix. The durable proposed promotion contract is [ADR 0012 / PR #50](https://github.com/alex-1974/quantities-d/pull/50); target real is deferred and implementation remains selective.
