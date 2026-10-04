# R15 P3 qualification

This directory qualifies the already-integrated explicit TargetRep conversion
surface for proposed ADR 0012. It does not add API or broaden the selected pair
matrix.

The first baseline separates two questions:

1. public abstraction overhead: compare the public request to the same
   package-internal exact conversion kernel;
2. identity code generation: where semantics are identical, compare the public
   request and private kernel to a native scalar reference.

Current representative paths:

- signed long to long equal-scale identity;
- signed long to long nonidentity quarter-scale conversion;
- double to float equal-scale target conversion.

The nonidentity benchmark uses values divisible by four so the checked
conversion succeeds exactly on every iteration. This isolates public-carrier
overhead from failure-path frequency. Correctness and inexact/failure behavior
remain covered by the independent Fraction qualification gates.

Optimized builds retain bounds checks. Benchmark ratios are interpreted only
within the same runner/compiler invocation. Hosted-runner wall-clock results are
evidence for large regressions and compiler differences, not publication-grade
absolute timing.

Run with:

    bash tests/r15-p3/run.sh dmd
    bash tests/r15-p3/run.sh ldc2

The workflow records compiler and CPU context, executable/object size, repeated
runtime medians and spread, plus disassembly of fixed extern(C) probe symbols.
