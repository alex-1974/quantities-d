# R15 — Unit Declaration Metaprogramming

Status: active research

Issue: #10

## Question

How much D metaprogramming should quantities-d use for static Unit declaration
and catalogue construction?

The objective is not maximum metaprogramming. The objective is the smallest
mechanism that removes real boilerplate while preserving visible exact
semantics, useful diagnostics, CTFE, and acceptable compile-time cost.

## Baseline

M1 is accepted and merged to `develop`.

Production Unit declarations currently use the structural contract:

```d
struct Kilometre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1000, 1);
}
```

This is candidate A and the control against which every abstraction is judged.

## Reference set

Every viable candidate must represent exactly:

| Unit | Exact scale in metres |
| --- | ---: |
| metre | 1 / 1 |
| kilometre | 1000 / 1 |
| centimetre | 1 / 100 |
| millimetre | 1 / 1000 |
| international foot | 381 / 1250 |
| US survey foot | 1200 / 3937 |

The foot definitions are deliberately non-decimal controls.

## Candidates

### A — explicit structs

Control. Maximum transparency, maximum repeated declaration structure.

### B — Unit template / alias

Investigate whether a normal template can own the repeated structural contract
while leaving Dimension and exact ratio visible at the declaration site.

### C — exact SI-prefix composition

Investigate a compile-time decimal-prefix mechanism based entirely on exact
integer/rational arithmetic. Treat this as a possible complement to A/B rather
than assuming it should define every Unit.

### D — descriptor-driven declaration

Investigate whether a descriptor adds enough value for family enumeration,
metadata, generated validation, or later symbols to justify another abstraction
layer.

### E — mixin / string mixin

Challenger only. Reject unless it solves a concrete requirement materially
better than templates, aliases, traits, `static if`, and `static foreach`.

## Experiments

1. declaration/readability probe;
2. structural validation probe;
3. exact scale/normalization probe;
4. Unit-family `AliasSeq` probe;
5. pairwise `static foreach` matrix;
6. compile-negative diagnostic comparison;
7. CTFE and attribute probe;
8. public type-name / diagnostic inspection;
9. DMD/LDC compile-time comparison where candidates materially differ;
10. optional symbol/name metadata boundary probe.

## Guardrails

- no runtime Unit registry;
- no unit parsing or formatting;
- no floating Unit definitions;
- no broad SI catalogue;
- no change to `Quantity!(Spec, Rep)` storage;
- no string mixin merely to reduce line count;
- no claim of compile-time or zero-overhead superiority without measurement.

## Promotion gate

For each candidate record:

- KEEP — suitable as the primary M2 mechanism;
- COMPLEMENT — useful for a narrower role;
- REJECT — worse than a simpler mechanism;
- DEFER — potentially useful but not justified by M2.

M2 production work starts only after this comparison has a clear result.
