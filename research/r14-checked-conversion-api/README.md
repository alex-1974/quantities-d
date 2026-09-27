# R14 — Checked Conversion API

Status: active research

## Question

What is the smallest public conversion vocabulary that fully implements
ADR 0005 without weakening the CTFE/UFCS requirements accepted by ADR 0006?

## Fixed semantic constraints

R14 does not reopen the following decisions:

- `Quantity!(Spec, Rep)` stores the Spec canonical value.
- Unit scale is exact rational compile-time metadata.
- non-canonical Unit conversion is explicit;
- potentially lossy conversion has caller-visible intent;
- integral conversion never silently truncates, wraps, or rounds;
- overflow is distinct from inexactness;
- explicit rounding is caller-selected;
- CTFE and UFCS are hard requirements;
- no runtime Unit/Spec metadata is added.

## Candidate result vocabulary

The initial probe will compare a compact value/status result:

```d
enum ConversionStatus
{
    exact,
    inexact,
    overflow
}

struct ConversionResult(T)
{
    T value;
    ConversionStatus status;
}
```

against APIs that encode exact-required failure separately.

The result type must remain a plain value type and usable in CTFE and
`@safe pure nothrow @nogc` code.

## Candidate operation vocabulary

The first comparison is intentionally small.

### A — intent in operation name

```d
q.checkedIn!Metre
q.exactIn!Metre
q.roundedIn!(Metre, RoundingMode.floor)
```

Construction follows the same vocabulary through free functions usable by
UFCS:

```d
value.checkedQuantity!(Length, Kilometre)
value.exactQuantity!(Length, Kilometre)
value.roundedQuantity!(Length, Kilometre, RoundingMode.floor)
```

### B — one operation plus policy

```d
q.inUnit!(Metre, ConversionPolicy.checked)
q.inUnit!(Metre, ConversionPolicy.exact)
q.inUnit!(Metre, ConversionPolicy.rounded, RoundingMode.floor)
```

Construction mirrors the same policy form.

### C — checked primitive plus derived conveniences

One checked primitive exposes status. Exact-required and rounded operations are
thin wrappers with explicit names.

This candidate is attractive if it keeps the semantic kernel singular while
the public API remains readable.

## Evaluation gates

A candidate is promotable only if it demonstrates:

1. natural UFCS at normal call sites;
2. CTFE construction and extraction;
3. DMD 2.111 and LDC 1.41 compatibility;
4. exact/inexact/overflow distinction;
5. full signed integral range;
6. no unsafe `-long.min`;
7. cross-cancellation before checked integral multiplication;
8. all four rounding modes for positive and negative values;
9. floating-source semantics consistent with ADR 0005;
10. compile-negative invalid Unit/Spec boundaries;
11. no runtime metadata or per-value storage overhead;
12. an external-consumer call site that remains understandable without reading
    implementation internals.

## Initial bias

Candidate C is the starting hypothesis, not a decision.

A single checked semantic kernel reduces the risk that exact-required and
rounded paths drift apart. Named convenience operations can then express caller
intent without forcing users to manipulate policy enums at every call site.

Evidence, not this preference, decides R14.


## Probe 1 — API shape

Implemented candidates:

- A: named intent operations with independent implementations;
- B: one operation parameterized by a conversion-policy enum;
- C: named intent operations layered over one checked primitive.

All three probes use the same deliberately trivial semantic kernel. This first
probe tests call shape, UFCS, CTFE and compiler acceptance only; it does not yet
claim conversion-algorithm correctness.

Run:

```bash
cd research/r14-checked-conversion-api
bash scripts/run.sh
```

### Early structural observation

A and C expose essentially the same readable call sites. Their important
difference is internal: C makes checked conversion the semantic primitive and
derives exact/rounded behavior from it.

B exposes policy machinery at ordinary call sites and still needs a separate
rounding-mode argument for the rounded case. It therefore has no demonstrated
surface-area advantage yet.
