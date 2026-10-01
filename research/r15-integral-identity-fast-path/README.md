# R15 Probe 19 — floating-source to long identity fast path

Research only, preserving the selected Probe 16 public request contract and Probe 18 floating target paths. Dispatch specializes exactly equal normalized Unit ratios; other ratios retain the Probe 13 composed rational kernel. Admitted sources remain float, double and qualified real; long/ulong to long remain excluded.

The source tuple is decoded without an intermediate floating target. Finite exact sig × 2^e is compared against the signed long endpoint before any rounding. Nonnegative exponents use guarded unsigned shifts and a shifted bound; negative exponents use quotient/remainder and explicit shift >= 64 branches. Fractional checked/exact outcomes have no value; all four rounded policies retain inexact status. Nearest ties away handles shifts 64 and larger separately. Integer endpoint bounds ensure rounded in-range values stay in range. No new trusted block or floating-to-long cast.

Float/double ordinary source CTFE remains rejected. Tuple arithmetic remains CTFE-capable. Qualified real reuses layout-free frexp/ldexp decomposition and normalization; the binary64-like real qualification is a code path, not measured platform evidence.

Validation: independent Python Fraction API and tuple oracle, all float/double encoded exponent fields with signed selected fraction tails, real endpoints and subnormals, random represented sources, shift transitions 63/64/65, ties, all policies and range-before-rounding witnesses. Existing Probes 14, 15, 16 and 18 remain regression gates in debug, release and optimized builds. Compiler attributes and qualified sources are consumer gates.

Performance protocol: same-executable normalized API versus unchanged generic kernel control, 8192 precomputed inputs, per-input equality, warmup, 7 alternating rounds and checksum sink. Checked failure-heavy represented values near ±[1,2) and rounded value-producing floor requests are measured separately from checked integer-success corpora: all 8192 exactly represented integers from -4096 through 4095, for float/double/qualified real. Primary optimized builds retain bounds checks. No C++ parity or controlled cross-compiler comparison claim. Codegen records callable checked and floor wrappers, follows direct calls and tail jumps, and checks no reachable historical composed/integral kernel on identity paths. Counts are observations, not thresholds. Three compile/link rounds record baseline/consumer wall time and peak RSS.

Results pending CI. No production promotion or API freeze in this slice.
