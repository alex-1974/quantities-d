# ADR 0008 — Integral Arithmetic Range Classes and Checked Class-O Semantics

- Status: Accepted
- Date: 2026-09-29
- Research: R04.14 — Class-O checked arithmetic
- Issue: #20
- Related: ADR 0001, ADR 0004, ADR 0005, ADR 0007

## Context

M3 already admits direct integral arithmetic only when compile-time range analysis
proves that every result for every representable operand value fits a built-in
result Rep. Product and quotient work also separates semantic result resolution,
physical Dimension, exact Unit rescaling, and representation selection.

That rule deliberately leaves operations unavailable when their complete
mathematical result range exceeds every built-in integral Rep. R04.14 examined
whether those operations should remain unavailable, trap, wrap, widen through a
new public integer type, or use explicit value-dependent checked operations.

The research also evaluated exact canonical rescaling, result-carrier shape,
CTFE, generated code, and checked multiplication on the baseline DMD and LDC
toolchains.

## Decision

### 1. Integral arithmetic has three availability classes

For an integral arithmetic operation after semantic validity and exact result
relationships have been established:

- **Class W**: a built-in D integral ResultRep contains the complete mathematical
  result range for every representable operand value. The ordinary direct
  operation may be available.
- **Class O64**: no built-in ResultRep contains the complete operand-domain
  result range, but the operation has a meaningful built-in 64-bit result
  domain for individual runtime values. A named checked operation may be
  available and reports value or overflow.
- **Class OM**: the mathematical result domain cannot be represented by a
  semantically neutral built-in 64-bit result type. The operation remains
  unavailable until quantities-d deliberately adopts a wider public integer
  representation.

A checked operation does not make an invalid semantic operation valid.
Dimension, Spec/relation, Unit, and canonical-rescale validation happen before
representation and runtime arithmetic.

### 2. Direct operators remain total over their admitted operand types

If a direct integral quantities-d arithmetic operator compiles, overflow is
impossible for every value representable by its operand Reps.

Class-O support therefore does not weaken existing direct-operator gates.
Class O64 uses a named checked path. Class OM is not made available by wrapping,
trapping, assertions, or implicit allocation.

### 3. Checked Class-O results have a narrow failure space

A Class-O64 operation reports only states that the operation can actually
produce. For checked addition, subtraction, or multiplication whose only
value-dependent representation failure is range overflow, the semantic result is:

- value;
- overflow.

The default-constructed result carrier must be a failure state rather than
implicit success.

quantities-d does not introduce a universal arithmetic-status enum merely to
make unrelated operations look uniform. Existing exact product and division
results retain their own exactness/division failure domains.

### 4. Exact canonical rescaling classifies the final mathematical result

For an exact rational rescale, checked evaluation must not equate overflow of a
naive machine-width intermediate with overflow of the final mathematical result.

The integral kernel therefore:

1. handles a zero multiplicative factor before unnecessary multiplication;
2. determines sign independently from magnitude arithmetic;
3. converts signed operands to unsigned magnitudes without losing the minimum
   signed value;
4. cancels denominator factors against operand magnitudes before multiplication;
5. uses normalized ExactRatio invariants rather than repeating algebra already
   proven at compile time;
6. reports inexactness when an exact integral result still has an uncancelled
   denominator;
7. checks only the remaining magnitude multiplication;
8. applies the final signed result limit, including the asymmetric minimum
   signed magnitude;
9. reconstructs the exact signed value only after those checks.

This is semantic correctness first and an optimization second.

### 5. Compile-time facts must remain visible to the generated kernel

Canonical rescale ratios are compile-time structure. Production kernels should
express materially different cases with templates and `static if` rather than
benchmarking a more dynamic surrogate and assuming equivalent specialization.

In particular, identity numerator/denominator cases must not retain artificial
checked multiply/divide work when compile-time structure proves it unnecessary.

### 6. Backend specialization is subordinate to common semantics

The semantic checked-arithmetic kernel remains compiler-independent.

A narrow backend specialization is permitted when measurements show a persistent
backend capability difference and both paths implement the same result
classification. R04.14 found that LDC 1.41 lowers `core.checkedint` 64-bit
checked multiplication efficiently, while the tested DMD versions have
materially weaker multiplication lowering.

A backend capability gate such as `version (LDC)` is preferable to a ladder of
DMD version checks for this persistent difference. Version gates remain
appropriate for demonstrated version-bounded defects.

Compiler code-generation quirks must not determine the public result carrier or
API shape.

### 7. Public operation names are promoted incrementally

The production Class-O64 arithmetic family promotes `checkedAdd`, `checkedSub`,
and `checkedMul` for homogeneous `long` and homogeneous `ulong` Quantity
arithmetic. The names compose with the existing `checkedQuantity` conversion
vocabulary and remain natural under UFCS, while ordinary direct operators
continue to mean compile-time-proven total arithmetic.

`checkedMul` additionally owns product-relation resolution and exact canonical
rescaling. Its internal checked-magnitude primitive uses `core.checkedint.mulu`
on LDC and the portable division-bound implementation on DMD; both paths retain
the same public result classification and CTFE contract.

## Alternatives considered

### Make direct operators checked

Rejected because it would make the meaning and return type of ordinary
arithmetic depend on representation-range classification and would weaken the
existing total-direct-operator contract.

### Trap or assert on Class-O overflow

Rejected because overflow is a normal value-dependent outcome for an otherwise
valid Class-O64 operation.

### Wrap on overflow

Rejected because it violates mathematical quantity semantics.

### Remove integral arithmetic whenever the complete range does not fit

Rejected for O64 because many individual operand pairs have valid built-in
64-bit results and can be served safely by an explicit checked operation.

### Introduce a wider public integer representation now

Rejected for M3 because R04.14 did not establish a justified public wider-integer
representation, ABI, dependency, or consumer requirement.

### Reuse exactMul as the overflow-checking API

Rejected because exact canonical rescaling and representational overflow are
distinct concerns. Existing `exactMul` semantics must not be silently
repurposed.

### Universal ArithmeticStatus

Rejected because addition/subtraction/multiplication overflow, exact product
inexactness, and division-by-zero do not share the same genuine failure domain.

## Consequences

- Existing Class-W direct arithmetic remains source- and semantics-compatible.
- O64 can be added incrementally through explicit checked operations without
  weakening direct operators.
- OM remains an intentional compile-time boundary.
- Result carriers remain operation-specific and invariant-owning.
- Exact rescaling may require more algebraic structure than a naive
  multiply-then-divide implementation.
- Compiler-specific fast paths remain internal and removable.
- A future wider-integer decision can extend OM without redefining W or O64.

## Validation evidence

R04.14 validated the decision on the workspace baseline compilers and additional
DMD comparison builds.

Evidence includes:

- checked add/sub/mul result-contract probes;
- DMD and LDC generated-code inspection;
- runtime checked-arithmetic benchmarks;
- exact canonical-rescale probes with compile-time ratios;
- zero-numerator and signed-endpoint cases;
- independent arbitrary-precision oracle comparison over 10,004 cases per
  baseline compiler;
- DMD and LDC consumer builds;
- bounds-check enabled and disabled measurements.

The research rejected custom inline assembly, split-32 multiplication, ImportC
overflow builtins, software 128-bit arithmetic, signed-via-unsigned replacement
kernels, and public result-carrier ABI changes as production strategies.

The corresponding cross-library D guidance is recorded in the workspace
`DLANG_PRACTICES.md`; the measured DMD/LDC checked-multiplication boundary is
recorded in `TOOLCHAIN_ISSUES.md`.
