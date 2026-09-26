# R09 — B versus C cost probe

Research-only probe for quantities-d issue #4.

## Question

What measurable compile-time, binary/code-size, and optimized-code costs differ
between the remaining R01 representation candidates?

- B: `Quantity!(Spec, Unit, Rep)`
- C: `Quantity!(Spec, Rep)` with explicit source-unit conversion boundaries

This probe must compare equivalent semantics. It is not a benchmark of a broad
units library.

## First workload

Use the same:

- quantity Specs;
- unit set;
- representation types;
- value count;
- arithmetic intent.

Generate separate B-only and C-only executables so compiler time, peak RSS and
binary size are not mixed.

The initial workload intentionally uses simple same-unit arithmetic and explicit
conversion boundaries. Later scaling points increase instantiation count.

## Metrics

For DMD 2.111 and LDC 1.41:

1. wall-clock compile/link time;
2. peak resident memory during build;
3. stripped executable size;
4. optimized assembly/code generation for representative kernels.

Runtime microbenchmarks are deferred unless optimized code generation shows a
reason to expect a material difference.

No code here is proposed public API.
