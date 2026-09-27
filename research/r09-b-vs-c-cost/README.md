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


## First measured series — 2026-09-27

Environment:

- Linux x86_64, kernel 6.17.0-22-generic;
- DUB 1.40.0;
- DMD 2.111.0;
- LDC 1.41.0;
- five repetitions per compiler/configuration with alternating B/C order.

Observed medians:

| Compiler | Model | elapsed | peak RSS |
|---|---:|---:|---:|
| DMD | B | 0.19 s | 56,564 KiB |
| DMD | C | 0.18 s | 56,208 KiB |
| LDC | B | 0.19 s | 90,172 KiB |
| LDC | C | 0.17 s | 89,348 KiB |

Binary sizes were completely stable across repetitions:

| Compiler | Model | binary | stripped |
|---|---:|---:|---:|
| DMD | B | 935,960 B | 672,088 B |
| DMD | C | 916,736 B | 660,200 B |
| LDC | B | 634,448 B | 433,024 B |
| LDC | C | 634,448 B | 433,024 B |

Interpretation is deliberately limited:

- compile-time samples are too short/noisy for a strong performance claim;
- peak-RSS differences are small in this tiny workload;
- DMD shows a reproducible B binary-size increase of 19,224 B unstripped
  (~2.10%) and 11,888 B stripped (~1.80%);
- LDC emits identical B/C executable sizes in this workload.

The DMD size difference must be explained by symbol/code-generation inspection
before it is treated as a representation cost. The next step is therefore
optimized symbol/assembly comparison, not a larger benchmark or a B/C decision.
