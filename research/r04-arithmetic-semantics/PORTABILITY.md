# R04 — Portability and specialization matrix

## Principle

quantities-d defines a portable public semantic contract.

Implementation details may be specialized by compiler family, compiler version,
target architecture, or build mode when measurements demonstrate a real
difference.

Specialization must be evidence-based. Do not create speculative compatibility
branches.

## Axes

Record research results against:

- compiler family: DMD / LDC;
- compiler version;
- frontend version where relevant;
- target architecture;
- operating system where it can affect ABI or floating behavior;
- debug/release and relevant optimization configuration;
- runtime versus CTFE.

## Current baseline

The currently measured baseline is:

- DMD 2.111 on x86_64;
- LDC 1.41 on x86_64;
- Ubuntu/Linux;
- debug and release.

Results from this baseline are not automatically claims about AArch64 or future
compiler versions.

## Specialization rule

A specialized implementation path is justified only when:

1. a reproducible behavioral or performance difference exists;
2. the affected compiler/version/architecture range can be identified;
3. the specialization preserves the public semantic contract;
4. both specialized and generic paths have tests;
5. the branch does not silently create different public semantics.

Compiler/version/architecture specialization is preferable to weakening the
portable API contract when a defect or missed optimization is narrowly scoped.

## Version ranges

Prefer capability/evidence boundaries rather than enumerating every compiler
release.

Example policy shape:

- known baseline implementation through version X;
- specialized path beginning/ending at a measured compiler change;
- later versions inherit the newest validated path until evidence requires a
  new boundary.

Do not optimize separately for every release.

## Architecture

Architecture-specific paths are permitted for measured needs such as:

- floating-point lowering differences;
- SIMD/vectorization;
- integer overflow primitives;
- alignment or ABI behavior;
- code-generation quality.

The public Quantity representation and semantic contract remain architecture
independent unless an explicit future ADR states otherwise.

## R04 implication

The DMD 2.111 x86_64 release anomaly observed for
`+infinity + -infinity` must be isolated before deciding whether it requires:

- no action because the probe itself enabled an inappropriate optimization
  assumption;
- a DMD/version-specific workaround;
- a build-configuration restriction;
- or a narrower public exceptional-floating contract.
