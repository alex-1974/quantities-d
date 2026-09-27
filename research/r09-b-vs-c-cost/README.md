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


## DMD section inspection — 2026-09-27

The first section-level inspection explains much of the DMD size signal.

Relative to C, B adds only 816 bytes of `.text`, while larger increases occur
in dynamic-symbol/relocation/data infrastructure, including approximately:

- `.dynstr`: +5,941 B;
- `.rela.dyn`: +2,304 B;
- `.data`: +3,696 B;
- `.dynsym`: +1,392 B;
- smaller increases in GNU hash/version and unwind metadata.

`.rodata` is slightly smaller for B in this run.

This is consistent with additional concrete D type/symbol materialization for
B's Unit-bearing type identity rather than a large numerical-code penalty.
That interpretation is not yet proven. A model-specific symbol-set comparison
is the next probe.

The LDC byte-identical result remains important: any DMD materialization cost
observed here is compiler/code-generation behavior, not an unavoidable runtime
storage cost of B.


## DMD model-specific symbol result — 2026-09-27

The symbol comparison strongly supports the materialization hypothesis.

Observed unique-symbol counts:

- B: 2,747 total, 82 B-only;
- C: 2,689 total, 24 C-only.

The controlled probe has four Specs and five Units. B therefore creates twenty
distinct `QuantityB!(Spec, Unit, double)` concrete types. For each observed B
quantity instantiation, DMD emits model-specific infrastructure including:

- `__xopEquals`;
- `__xtoHash`;
- a TypeInfo initializer;
- a struct initializer.

C creates only four `QuantityC!(Spec, double)` concrete quantity types, one per
Spec, with corresponding type infrastructure. Unit diversity instead appears
primarily in boundary conversion instantiations such as `fromUnit!(Spec, Unit)`.

This explains the direction of the DMD section-size result: B's Unit-bearing
type identity increases the number of concrete D types and therefore DMD
runtime/type/symbol materialization. The observed executable-size delta is not
evidence of per-value storage overhead and only a small fraction is additional
`.text`.

LDC's byte-identical B/C executables show that this materialization cost is not
an unavoidable property of the semantic model. It is currently a
compiler-sensitive implementation/code-generation cost.

Next R09 discriminator:

1. measure growth as the number of concrete Spec×Unit combinations increases;
2. determine whether DMD TypeInfo/equality/hash emission can be suppressed or
   structurally avoided for the intended quantity value type;
3. keep runtime arithmetic benchmarking secondary unless generated numerical
   code diverges materially.


## Scaling probe

`scripts/measure-scaling.sh` generates controlled B/C source programs for
N = 1, 5, 10, 20, 50, 100, and 200 unit variants. It deliberately uses one
Spec so N maps directly to B's number of concrete `QuantityB!(Spec,Unit,double)`
types, while C retains one `QuantityC!(Spec,double)` type and grows only
boundary conversion functions.

The probe uses direct compiler invocation rather than DUB so the measured
compile/link time is not dominated by DUB startup. It records three repetitions
per point by default for DMD and LDC, alternating B/C order, plus binary and
stripped size and quantity-related TypeInfo/equality/hash symbol counts.

This is a synthetic scaling experiment. It measures the marginal compiler/type
materialization behavior isolated by the previous probe; it is not intended to
model a complete application.


## Scaling result — 2026-09-27

The N = 1, 5, 10, 20, 50, 100, 200 scaling series materially strengthens
the R09 result and refines the earlier LDC interpretation.

### DMD

With one Spec and N Units, B's measured quantity-related symbol counts scale
directly with N:

- quantity symbols: 3N;
- TypeInfo symbols: N;
- `__xopEquals`: N;
- `__xtoHash`: N.

C remains constant at three quantity-related symbols and one each of TypeInfo,
equality and hash across the full series.

At N=200:

- B stripped binary: 925,744 B;
- C stripped binary: 747,584 B;
- delta: +178,160 B for B;
- B unstripped: 1,295,208 B;
- C unstripped: 1,033,024 B;
- delta: +262,184 B for B.

A linear fit over the sampled stripped-size delta is approximately 892 bytes
per additional Unit-bearing B type. This is descriptive for this synthetic
probe and compiler/toolchain, not a promised universal per-type cost.

Compile-time medians remain close at small N. At N=200, B is 0.20 s versus
0.18 s for C, with peak RSS about 58,044 KiB versus 56,256 KiB.

### LDC

The earlier small workload suggested byte-identical B/C output, but the scaling
probe shows that conclusion does not generalize.

At N=200:

- B median compile/link time: 0.35 s;
- C: 0.19 s;
- B peak RSS: about 104,548 KiB;
- C: about 94,612 KiB;
- B stripped binary: 438,712 B;
- C: 433,016 B;
- B unstripped: 657,480 B;
- C: 634,424 B.

The GNU `nm` patterns used for DMD do not expose corresponding LDC
quantity-TypeInfo symbols in this optimized binary, so zero counts here mean
"not observed by this probe", not "LDC creates no compile-time type cost".

### R09 interpretation

B has a demonstrated compiler/type-instantiation scaling cost because Unit is
part of every concrete quantity type. The cost is especially visible in DMD
runtime/type metadata and becomes visible in LDC compile resources as N grows.

C keeps the number of concrete quantity types tied primarily to Spec/Rep rather
than Spec/Unit/Rep and therefore scales more gently with unit diversity in this
probe.

This remains a cost result, not by itself a semantic design verdict. B provides
source-unit identity in the type; C deliberately does not. The next question is
whether DMD's generated TypeInfo/equality/hash materialization can be avoided
for the intended B value type, and whether realistic consumer workloads reach
enough distinct Spec×Unit combinations for the measured cost to matter.


## DMD TypeInfo isolation probe

`scripts/probe-typeinfo.sh` compares three B-shaped structs at N = 1, 20, 100,
and 200 Unit-bearing concrete types:

- `baseline`: compiler-generated equality/hash behavior;
- `explicit`: explicit value equality and hash implementation;
- `noeq`: equality explicitly disabled.

The experiment asks whether the DMD metadata-size slope is merely an artifact
of synthesized equality/hash helpers or follows from the concrete struct type
identity itself. A compile failure is itself evidence if suppressing a generated
operation is incompatible with the intended value-type contract.

The probe does not propose any of these variants as public API. In particular,
an optimization is not acceptable merely because it reduces binary size if it
weakens ordinary quantity value semantics.
