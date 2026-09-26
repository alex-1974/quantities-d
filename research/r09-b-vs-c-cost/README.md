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


## Measurement protocol

After the semantic control workload passes without diagnostics, collect release
build evidence with `scripts/measure.sh`.

The script:

- measures DMD and LDC separately;
- measures B and C in separate builds;
- defaults to five repetitions;
- alternates B/C order to reduce systematic warm-cache bias;
- records `/usr/bin/time` elapsed time and peak RSS;
- records normal and stripped executable size;
- records compiler/DUB/system environment;
- retains raw TSV data under `results/`.

Run:

```bash
RUNS=5 ./scripts/measure.sh
```

Do not commit generated `results/` until the run has been inspected for
methodological problems. The first measurement series is evidence collection,
not yet a performance conclusion.
