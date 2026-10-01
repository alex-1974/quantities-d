# R15 Probe 19 — floating-source to long identity fast path

Research only, preserving the selected Probe 16 public request contract and Probe 18 floating target paths. Dispatch specializes exactly equal normalized Unit ratios; other ratios retain the Probe 13 composed rational kernel. Admitted sources remain float, double and qualified real; long/ulong to long remain excluded.

The source tuple is decoded without an intermediate floating target. Finite exact sig × 2^e is compared against the signed long endpoint before any rounding. Nonnegative exponents use guarded unsigned shifts and a shifted bound; negative exponents use quotient/remainder and explicit shift >= 64 branches. For a negative exponent, an integer quotient equal to the endpoint with nonzero remainder is outside range; a smaller quotient stays within it. Shifts >=64 imply magnitude <1. For nearest ties away, a shift of 64 compares the full significand to 2^63; a larger shift is strictly below half. Fractional checked/exact outcomes have no value; all four rounded policies retain inexact status. Nearest ties away handles shifts 64 and larger separately. Integer endpoint bounds ensure rounded in-range values stay in range. No new trusted block or floating-to-long cast.

Float/double ordinary source CTFE remains rejected. Tuple arithmetic remains CTFE-capable. Qualified real reuses layout-free frexp/ldexp decomposition and normalization; the binary64-like real qualification is a code path, not measured platform evidence.

Validation: independent Python Fraction API and tuple oracle, all float/double encoded exponent fields with signed selected fraction tails, real endpoints and subnormals, random represented sources, shift transitions 63/64/65, ties, all policies and range-before-rounding witnesses. Existing Probes 14, 15, 16 and 18 remain regression gates in debug, release and optimized builds. Compiler attributes and qualified sources are consumer gates.

Performance protocol: same-executable normalized API versus unchanged generic kernel control, 8192 precomputed inputs, per-input equality, warmup, 7 alternating rounds and checksum sink. Checked failure-heavy represented values near ±[1,2) and rounded value-producing floor requests are measured separately from checked integer-success corpora: all 8192 exactly represented integers from -4096 through 4095, for float/double/qualified real. Primary optimized builds retain bounds checks. No C++ parity or controlled cross-compiler comparison claim. Codegen records callable checked and floor wrappers, follows direct calls and tail jumps, and checks no reachable historical composed/integral kernel on identity paths. Counts are observations, not thresholds. Three compile/link rounds record baseline/consumer wall time and peak RSS.

## Validated result and decision

**Decision: adapt.** The identity specialization is justified for selective future production integration. Keep the generic composed path for nonidentity ratios and the selected request contract. This research snapshot does not admit any additional Rep pair and does not freeze the API.

Tested code: `87ada2ff152b9972ac2f8a0fd0c8eab76bc25c6d`. [CI run 36852877671](https://github.com/alex-1974/quantities-d/actions/runs/36852877671) passed DMD 2.111.0 and LDC 1.41.0, each in debug, release and optimized builds. Per build: **183,522 API pairs / 367,044 directional comparisons plus 26,200 tuple comparisons**, zero mismatches. Across six builds: 2,359,464 new comparisons. Probes 14/15/16/18 also passed under the new shadow API in all six builds. Runtime attributes, qualified sources, CTFE rejection and tuple CTFE assertions passed. Both runners report binary80 real `(64,-16381,16384)`; binary64-like real remains unmeasured.

Both jobs report AMD EPYC 7763 64-Core Processor on separate hosted runners. DMD uses `-release -O -inline -boundscheck=on`; LDC uses `-release -O3 -boundscheck=on`. Values below are same-executable medians in ns per normalized observation. No CPU affinity/frequency control or controlled cross-compiler comparison is claimed.

| Corpus / API | DMD API / generic control (ns) | LDC API / generic control (ns) |
| --- | ---: | ---: |

| float → long, checked integer success | 46.26 / 6315.97 | 4.70 / 2023.29 |
| double → long, checked integer success | 46.31 / 8996.39 | 4.80 / 2963.61 |
| real → long, checked integer success | 112.59 / 4706.63 | 63.27 / 1515.20 |
| double → long, checked fractional/edges | 30.10 / 5631.43 | 5.18 / 1782.87 |
| double → long, floor fractional/edges | 50.37 / 5595.18 | 5.32 / 1805.15 |
| real → long, floor fractional | 88.70 / 6195.28 | 27.75 / 2150.00 |
| double → long, floor foot (nonidentity) | 5114.21 / 5061.18 | 1747.73 / 1738.79 |

The checked double integer-success corpus improves by about 194× (DMD) and 617× (LDC) versus the unchanged generic kernel on these inputs. The real integer-success corpus improves by about 42× / 24×. Nonidentity floor-foot ratios are 1.010 / 1.005; these small offsets are observations, not a regression finding. All 19 benchmark cases pass per-input semantic equality and all timed checksums. Probe 18 inclusion fast paths remain active.

Codegen follows direct calls and direct tail jumps. All five checked/floor identity wrappers reach no historical composed/integral kernel; all five baseline wrappers do. DMD wrapper bodies have 59–60 instructions, six direct calls and 10–12 reachable functions; LDC float/double wrappers have nine instructions, one direct call and two reachable functions. LDC real wrappers have 55–63 instructions and one direct call. These are wrapper counts, **not total path instruction counts**. LDC keeps a helper call, so this is not a claim of full wrapper inlining. See [DMD assembly](codegen-dmd.txt), [LDC assembly](codegen-ldc.txt), and the full records in [results.json](results.json).

Median three-round compile/link costs (wall seconds / peak RSS KiB):

| Compiler | Import baseline | Selected-request consumer |
| --- | ---: | ---: |
| dmd-2.111.0 | 0.33 / 82220 | 0.35 / 82624 |
| ldc-1.41.0 | 0.94 / 166676 | 1.10 / 171392 |

Reproduction is the **Probe 19** step in [the research workflow](../../.github/workflows/r15-exact-unit-rescale.yml): it lists exact modules, import precedence, build flags and executable commands. The benchmark source fixes both input procedures, ordering, rounds and observations. Historical kernels serve as unchanged controls. New code/benchmarks must rerun this matrix; the result-recording commit only changes documentation and retained evidence.

Next scope: define the missing integral-source → integral-target pairs (`long` / `ulong` → `long`) under the same checked/exact/rounded request surface, then evaluate selective production promotion. Qualified real targets and broader pair semantics still belong to open R15 issue #42. No production API change or release qualification is implied by this result.

## Follow-up: integral Source admission

[Probe 20](../r15-integral-source-api/README.md) qualifies long/ulong → long for all six selected request forms, all rounding modes, exact Unit ratios, CTFE and runtime. It preserves the floating paths and records the resulting 5 × 3 pair matrix. Historical probes remain unchanged; promotion is selective.
