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


## DMD TypeInfo isolation result — 2026-09-27

The TypeInfo isolation probe rejects the simple hypothesis that B's DMD size
slope is mainly removable synthesized equality/hash machinery.

At N=200:

| variant | stripped | quantity symbols | TypeInfo | __xopEquals | __xtoHash |
| --- | ---: | ---: | ---: | ---: | ---: |
| baseline | 931,440 B | 600 | 200 | 200 | 200 |
| explicit | 1,040,848 B | 800 | 400 | 0 | 0 |
| noeq | 884,784 B | 400 | 200 | 0 | 200 |

Findings:

- Explicit user-defined equality/hash does not suppress the underlying concrete
  type metadata cost; in this probe it makes the result materially worse and
  doubles the observed TypeInfo-symbol count.
- Disabling equality removes the generated `__xopEquals` symbols and reduces
  stripped size by 46,656 B at N=200 versus baseline, but TypeInfo remains one
  per concrete quantity type and `__xtoHash` remains present.
- Therefore generated equality is a measurable component of the DMD B cost,
  but it is not the root cause.
- The persistent cost tracks the number of distinct
  `Quantity!(Spec, Unit, Rep)` struct types themselves.

The `noeq` variant is not an acceptable public-design optimization by default:
it weakens ordinary value semantics. The result is useful as causal isolation,
not as a recommended API.

R09 now has evidence that the B scaling cost cannot be removed merely by
providing or disabling equality/hash in the obvious way. Any further mitigation
would need to change how DMD materializes type information, how the public type
is represented, or how Unit participates in concrete type identity.


## Real-consumer type-count audit — geospatial workspace

The synthetic N=200 result is a stress discriminator, not a typical-consumer
estimate. An audit of current workspace semantics gives a more useful range.

### geodesy-d

Current geodesy-d separates several semantic linear roles:

- ellipsoid semi-major/minor axes and radius;
- ellipsoidal height;
- projected easting/northing;
- geocentric X/Y/Z;
- topocentric East/North/Up.

These roles do not all necessarily require distinct Quantity Specs. Some are
components of stronger coordinate types whose reference-system semantics remain
outside a generic quantities library. The current contract instead requires
participating linear values in an operation to use the same caller-selected
linear unit.

UTM is narrower: its public policy fixes easting, northing and ellipsoid axes to
metres.

Angles are an important existing counterexample to the source-unit-preserving
linear policy: `Angle`, `Latitude`, and `Longitude` already store radians
canonically and expose explicit degree/radian factories/accessors. This is
conceptually C-like storage, although these are domain-specific geodesy types
rather than quantities-d types.

Current geodesy scalar support is float/double/real. A library test suite may
instantiate all three, but a normal consumer commonly selects one Rep for a
given numerical path. Therefore multiplying every possible Spec × Unit × Rep
combination overstates ordinary application type count.

A plausible quantities-d integration should initially keep strong quantities at
semantic/API boundaries and preserve scalar numerical kernels. Under that
architecture, an individual geodesy consumer is much closer to the low tens of
concrete quantity types than to the N=100–200 stress cases unless it
deliberately mixes many source units and Reps in one binary.

### geo-d / geo3-d

The Euclidean geometry libraries intentionally support a wider scalar family,
including integral coordinate types. They also have exact-before-floating
metric policies for large integral coordinates. This makes blanket replacement
of geometry scalar parameters with unit-bearing Quantity types unattractive:
it would multiply concrete types by Unit and Rep while entangling unit
conversion with carefully designed numeric kernels.

The safer initial integration boundary is therefore typed physical inputs and
outputs around scalar geometry kernels, not unit-bearing replacement of every
Point/Vector coordinate scalar.

### raster-d / imagery-d

Resident raster x/y coordinates are sample/element coordinates, not physical
lengths, so raster-d itself should not create a broad linear-unit quantity
surface.

Imagery introduces physical/angular resolution only at geospatial metadata and
georeferencing boundaries. Its previously identified distinction between
linear resolution and angular resolution requires Spec-level semantic
separation, but does not imply hundreds of concrete unit-bearing quantity
types in a normal image-processing binary.

### Practical R09 range

For decision work, use three bands rather than treating N=200 as typical:

- N ≈ 5–15: ordinary focused consumer / one Rep / few units;
- N ≈ 20–50: broad geospatial consumer or tests combining several semantic
  quantities, units and Reps;
- N >= 100: stress/library-validation or unusually broad unit-heavy program.

This range is an architectural estimate from current workspace contracts, not
a measured census of downstream applications. The public design must still
remain viable at high N, but normal-consumer cost should be judged primarily
in the first two bands.


## R01 + R02 + R09 synthesis — representation decision candidate

The combined evidence now supports promoting candidate C as the M1 static
quantity representation:

`Quantity!(Spec, Rep)`, with a canonical unit defined by the Spec contract and
source Unit supplied at explicit construction/conversion boundaries.

This is not a claim that B is incorrect. B remains a coherent alternative whose
principal semantic distinction is persistent source-Unit identity in every
quantity type. The decision is that this distinction is not sufficiently
valuable for the current consumers to justify making Unit part of every
concrete quantity type.

### Evidence

- A is insufficient as the primary model because Unit does not replace the
  independent Spec semantic axis.
- B and C both meet zero-per-value-storage, CTFE and safety/attribute feasibility
  constraints in the probes.
- R02 demonstrates that canonicalization need not imply silent loss: exact,
  checked/loss-aware, and explicitly rounded conversion intents can preserve
  representability policy at the boundary.
- B needs the same conversion/loss machinery whenever units are mixed, so it
  does not eliminate the R02 problem.
- Current consumers benefit from Spec-level distinctions but generally do not
  require source Unit to remain part of the stored value's permanent type
  identity after an explicit normalization boundary.
- geodesy-d already demonstrates successful canonical storage for angular
  domain types (radians internally, degree/radian boundaries).
- strong-boundary / scalar-kernel architecture limits quantity proliferation
  and fits C naturally.
- R09 measures a real Unit-diversity scaling cost for B on both supported
  compiler baselines, especially DMD type/runtime metadata. C ties concrete
  quantity-type growth primarily to Spec and Rep instead.

### Required constraints on C

Selecting C is only safe if all of the following become normative M1 rules:

1. Every Spec has one explicit canonical Unit contract.
2. Unit identity is compile-time boundary metadata; it is not inferred from a
   scalar value.
3. Normatively exact Unit scales remain exact compile-time rational values.
4. Construction/conversion to canonical storage obeys the R02 conversion-intent
   policy.
5. Integral canonical storage may reject a source value that is not exactly
   representable; it must not silently truncate or round.
6. Explicit rounding, where offered, is caller-selected and separate from Unit
   identity.
7. Quantity storage remains exactly the Rep payload where the language permits;
   no runtime Unit/Spec field is added.
8. Domain/reference semantics such as CRS, datum, vertical reference frame and
   raster georeferencing remain outside Quantity.
9. Strong quantities protect boundaries; numerical kernels may explicitly
   extract canonical scalars.
10. The public API must not expose a raw-scalar constructor whose Unit would be
    ambiguous. Construction from a scalar must name or otherwise statically
    establish the source Unit.

### Consequences

B should remain documented as the rejected alternative for M1, not deleted from
research history. Future evidence could justify a distinct source-unit-preserving
type for a specialized use case, but it should not redefine the core Quantity
identity without a new ADR.

The next promotion step is an ADR plus an M1 implementation contract. Public
conversion names, generic Rep support, arithmetic rules and the minimal rounding
surface remain separate decisions and must not be invented by the representation
ADR.
