# R15 Probe 18 — exact identity/inclusion fast paths

Status: research implementation and codegen/cost qualification. Production is
unchanged; this does not freeze the API or promote the research branch wholesale.

## Selected specialization

Probe 17 measured the general exact-rational conversion cost even when the Unit
factor was one. A total-exact representation inclusion with an exact identity
Unit ratio needs neither rational composition nor target quantization.

The new helper specializes only:

| Source | Target | Unit condition | Result for finite source |
| --- | --- | --- | --- |
| float | float | Equal normalized numerator and denominator | Exact stored bits |
| double | double | Equal normalized numerator and denominator | Exact stored bits |
| float | double | Equal normalized numerator and denominator | Exact binary64 embedding |

Equal negative scales also compose to positive one. Equivalent normalized
metadata is recognized without requiring the same Unit type. NaN/infinity remain
`nonFinite` with no payload. Signed zero is preserved. No integer source, real
source, narrowing conversion or non-identity scale uses this specialization.
These cases retain the tested composed-rational kernel and its range/rounding
rules. Dimension/Spec/Unit validation still occurs at the public boundary.

Binary32 widening uses integer construction of the binary64 bits. Normal values
move the fraction by 29 bits and adjust the exponent bias; subnormals use a
nonzero-guarded highest-set-bit position to normalize their exact significand.
This performs no floating arithmetic or native widening instruction, so ambient
rounding/denormal modes cannot change the constructed target bits. The trusted
bit-copy boundary is reused unchanged. The helper is `@safe pure nothrow @nogc`.
Stored-bit access also retains the ordinary floating-path CTFE rejection; an
identity shortcut must not silently broaden that contract.

The shadow conversion module starts from Probe 16 and changes only its private
floating kernel dispatch. Request names/arity, carrier state and long-target
conversion remain unchanged. Historical Probe 15–17 code remains intact.

## Verification and measurement

The focused Fraction oracle covers all binary32 exponent fields, all binary64
exponent fields, both signs, normal/subnormal boundaries, every highest-set-bit
position of a binary32 subnormal, special values and 40,000 seeded random bit
patterns. It tests checked construction and extraction for all three paths.
Exact-required, qualifier and runtime/CTFE attribute gates remain in the consumer
and earlier API/oracle suites. Equal negative scales, normalized metadata and a
negative non-identity scale are explicit consumer cases.

CI runs debug, release and optimized bounds-on profiles on DMD 2.111.0 and LDC
1.41.0. For each build it runs the focused oracle, Probe 16's contract consumer,
Probe 15's 44,352 floating directions and Probe 14's 27,240 integral directions.

The benchmark extends Probe 17's same-semantics workload to eleven cases.
Every input must agree individually with the unchanged normalized composed
kernel; seven warmed rounds alternate API/control ordering over 8,192 inputs.
The three specialized cases measure the optimized public API against that
general-kernel control in the same executable. Other cases remain observational
controls. Flags are DMD `-release -O -inline -boundscheck=on` and LDC
`-release -O3 -boundscheck=on`. No bounds-off or relaxed-math profile is used.
Shared CI hosts have no affinity/frequency controls; tiny time differences are
not stable speedup or regression claims.

Callable non-inlined codegen wrappers retain runtime source arguments and a
payload/failure observation. GNU objdump records their assembly and follows
direct call chains. The gate requires a reachable composed kernel for each
baseline wrapper and none for each specialized wrapper. Instruction counts are
static wrapper counts, not retired instructions or performance thresholds.
Consumer compile/link wall time and peak RSS are sampled three times as in
Probe 17.

## Results

Tested code: `05cc790e5fcb0a869ef8ae02ef3597c14d1221b5`.
[CI 36829926170](https://github.com/alex-1974/quantities-d/actions/runs/36829926170) passed on both compilers. In each of debug,
release and optimized builds, 55,486 represented inputs / 157,366 focused API
comparisons pass with zero mismatches. The 44,352 floating and 27,240 integral
API directions and the contract/CTFE-negative gates also pass in every build.
All eleven benchmark cases agree per input and retain matching timed checksums.

Same-executable median batch time / input count:

| Path | DMD API / control ns | Control / API | LDC API / control ns | Control / API |
| --- | ---: | ---: | ---: | ---: |
| float_float_identity | 31.99 / 925.66 | 28.9× | 1.46 / 223.21 | 152.9× |
| double_double_identity | 24.98 / 1794.27 | 71.8× | 1.46 / 395.07 | 270.6× |
| float_double_identity | 33.84 / 1382.07 | 40.8× | 2.62 / 271.41 | 103.6× |

These large ratios measure avoidance of the general rational kernel on a proven
closed domain; they are not universal application speedups. The fastest values
approach the common checksum/normalization floor. Other cases use the original
kernel and show only small observational timing differences. Shared-runner noise
precludes compiler-to-compiler comparisons or tight regression thresholds.
Raw eleven-case distributions, build samples, flags, CPU details and codegen
summaries are preserved in [results.json](results.json).

Codegen confirms no reachable composed kernel along direct calls from any of
the three specialized wrappers; all three control wrappers reach that kernel.
LDC emits no helper calls in those specialized wrappers. DMD retains seven direct
helper calls in each wrapper, including scalar/Quantity carrier accessors.
That remaining compiler-specific overhead is observed and recorded, not hidden
by a weaker result contract or unchecked public path. Assembly is retained in
[codegen-dmd.txt](codegen-dmd.txt) and [codegen-ldc.txt](codegen-ldc.txt).

Whole-consumer compile/link medians for the same eight-call build probe:

| Compiler | Import baseline seconds | Consumer seconds | Baseline RSS KiB | Consumer RSS KiB |
| --- | ---: | ---: | ---: | ---: |
| DMD | 0.20 | 0.21 | 82,364 | 82,648 |
| LDC | 0.67 | 0.78 | 166,044 | 173,340 |

This small consumer exposes no new compile-cost blocker. It does not establish a
large-application budget; the retained raw samples and matched flags define the
scope. Measurements from separate Probe 17 runs are not controlled before/after
compiler-cost comparisons.

## Remaining work

Recommendation: **adapt** these three proven specializations for the eventual
selective production slice. Preserve the general path for every other case.
DMD retains carrier/helper calls that LDC inlines; controlled-host measurements
can determine whether targeted inlining changes are justified. Identity narrowing and integral floor
extraction are separate future candidates. Alternative real formats, broader
Rep admission, controlled-host repetition, independent consumers, root exports,
production Ddoc and selective production promotion remain outside this probe.

## Follow-up: integral identity cost

[Probe 19](../r15-integral-identity-fast-path/README.md) specializes floating-source → long for equal normalized Unit ratios. It preserves this request contract and the Probe 18 floating target paths; its independent oracle, success/failure benchmark corpora and codegen are qualified on DMD/LDC. No new Rep pair or production promotion is included.
