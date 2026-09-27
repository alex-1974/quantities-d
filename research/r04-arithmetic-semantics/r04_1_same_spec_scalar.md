# R04.1 — Same-Spec and scalar arithmetic probe

## Question

What result-Rep behavior does ordinary D arithmetic provide for the operations
that are semantically strongest candidates for M3?

The probe does not modify production `Quantity`. It establishes language
behavior before quantities-d chooses a policy.

## Operations

For a minimal local relative quantity wrapper, probe:

- `Q!R + Q!R`
- `Q!R - Q!R`
- `Q!R * scalar`
- `scalar * Q!R`
- `Q!R / scalar`

Then probe mixed representation pairs separately:

- signed integer widths;
- signed/unsigned combinations;
- integer with `float` / `double`;
- `float` with `double`.

## Questions to record

For every expression:

1. Does it compile on DMD 2.111 and LDC 1.41?
2. What is `typeof(expression)`?
3. Does the arithmetic itself use D's normal promotion before wrapping?
4. Can the result be represented as `Quantity!(Spec, typeof(rawExpression))`
   without an extra conversion?
5. Does CTFE behave identically?
6. Can the wrapper/operator remain `@safe pure nothrow @nogc`?
7. What happens for integer overflow?
8. What happens for integer division/truncation?
9. Are signed/unsigned promotions acceptable for a strong quantity API?
10. Do compiler diagnostics remain understandable?

## Candidate policies

### A — identical Rep only

Quantity/Quantity arithmetic requires identical Rep. Scalar operations require
the scalar to be accepted without changing Rep.

Pros: smallest semantic surface and predictable result identity.

Risk: unnecessarily restrictive and unlike ordinary D numerical code.

### B — normal D arithmetic result Rep

Compute the raw scalar expression and use its type as the result Rep.

Conceptually:

```d
alias ResultRep = typeof(lhs.canonicalValue + rhs.canonicalValue);
```

Pros: follows D and avoids maintaining a second promotion system.

Risk: D promotions, especially signed/unsigned and narrow integer behavior, may
be surprising or unsafe for strong quantities.

### C — quantities-specific promotion

Define an explicit promotion lattice.

Pros: maximum control.

Risk: large policy surface, compiler divergence risk, and duplication of
language semantics without demonstrated consumer need.

### D — mixed Rep requires explicit conversion

Same-Rep arithmetic is direct; differing Reps require the caller to normalize
first.

Pros: explicit and conservative.

Risk: ergonomic cost at numerical boundaries.

## Initial hypothesis

Do not adopt B merely because it is convenient. Prefer the smallest rule that
preserves normal numerical usability without creating silent representation
surprises. C requires strong evidence because it creates substantial library
policy.

## Required evidence

The experiment must emit a deterministic type/value matrix for both baseline
compilers and include compile-negative cases where a candidate intentionally
rejects an expression.

No candidate is promoted from this document alone.


## Observed baseline — 2026-09-27

The first probe was run successfully on DMD 2.111 and LDC 1.41. Both
compilers produced the same result types and values for every tested case.

Observed binary Rep results:

| Expression class | Result Rep |
|---|---|
| int + int / int - int | int |
| int + long / int - long | long |
| int + uint / int - uint | uint |
| int + double / int - double | double |
| float + double / float - double | double |

Observed scalar Rep results:

| Expression class | Result Rep / behavior |
|---|---|
| int * int | int |
| int / int | int, integer division |
| int * long / int / long | long |
| int * double / int / double | double |
| float * double / float / double | double |

The CTFE same-Rep addition probe also passed under both compilers.

### Immediate consequences

Candidate B (use ordinary D arithmetic result Rep) is implementation-simple and
compiler-stable for this matrix, but it is not automatically acceptable as the
public quantities-d rule.

Two cases require explicit hardening:

1. `int + uint -> uint`: negative signed values can cross into unsigned
   semantics merely because the other operand is unsigned.
2. `int / int -> int`: ordinary D division truncates. A quantity operation
   must not accidentally look like exact physical/numerical division while
   silently discarding a fractional result.

Therefore normal D promotion remains a candidate language mechanism, not yet an
accepted quantities-d semantic policy.

## Next boundary probes

Before choosing A, B, C, or D, test:

- negative int with uint for addition/subtraction;
- signed/unsigned width combinations near boundaries;
- int.min / -1 overflow behavior;
- multiplication overflow;
- division by zero behavior and diagnostics;
- narrow integer promotions (byte/ubyte/short/ushort);
- scalar multiplication where the scalar changes signedness;
- CTFE behavior for the same boundary cases;
- whether release-mode behavior changes any overflow observation.

The purpose is not to build checked arithmetic in R04.1. It is to determine
which raw language behaviors quantities-d may safely expose and which require
restriction or explicit policy.


## Boundary results — 2026-09-27

The boundary probes were run on DMD 2.111 and LDC 1.41 in debug and release
where applicable.

### Signed/unsigned promotion

Both compilers agreed:

| Expression | Result type | Observed value |
|---|---:|---:|
| `-1 int + 1 uint` | `uint` | 0 |
| `-1 int - 1 uint` | `uint` | 4294967294 |
| `-1 int * 1 uint` | `uint` | 4294967295 |

This demonstrates that ordinary D promotion can silently reinterpret negative
signed arithmetic into unsigned modular results.

### Narrow integer promotion

Both compilers agreed that byte/ubyte/short/ushort arithmetic promotes to
`int` for the tested operations:

- byte + byte -> int
- ubyte + ubyte -> int
- short + short -> int
- ushort + ushort -> int
- byte + ubyte -> int
- short + ushort -> int
- byte * byte -> int
- short / short -> int

This behavior is regular D arithmetic but means result-Rep identity is not
preserved for narrow integer Quantity representations.

### Multiplication overflow

`int.max * 2` produced `-2` with exit code 0 under both DMD and LDC, in
both debug and release builds.

Therefore ordinary signed integer multiplication overflow is observable as
wraparound for this probe and is not rejected merely by using debug builds.

### `int.min / -1`

Observed behavior:

| Compiler | Debug | Release |
|---|---|---|
| DMD 2.111 | runtime failure (program code -8; dub reports failure) | returns int.min |
| LDC 1.41 | runtime failure (program code -8; dub reports failure) | returns an unrelated observed int value |

The release-mode result is therefore not a stable semantic value across the
baseline compilers.

### Division by zero

Observed behavior:

| Compiler | Debug | Release |
|---|---|---|
| DMD 2.111 | runtime failure (program code -8) | compile-time compiler error in this probe |
| LDC 1.41 | runtime failure (program code -8) | executable ran and produced an unrelated observed int value |

The exact release manifestation is compiler/optimization dependent and must not
be exposed by quantities-d as a meaningful arithmetic contract.

## R04.1 conclusion

Candidate B — unconditionally expose ordinary D arithmetic and use the raw
expression type as ResultRep — is rejected as the complete public integer
arithmetic policy.

Reasons:

1. signed/unsigned promotion can silently reinterpret negative values;
2. integer division silently truncates;
3. signed overflow can wrap without failure;
4. `int.min / -1` has build-mode/compiler-dependent behavior;
5. division by zero has build-mode/compiler-dependent behavior;
6. narrow integer operations change representation type.

This does **not** mean quantities-d must implement checked integer arithmetic for
every operator. It means integer Quantity arithmetic needs an explicit policy
about which raw operations are permitted and where callers must opt into
checked/exact/rounded behavior.

## Narrowed policy candidates

The evidence now favors separating floating and integral arithmetic policy
rather than forcing one universal Rep rule.

### Integral Quantity arithmetic

Strong candidate:

- direct same-Spec addition/subtraction only under a deliberately defined
  integral safety/result rule;
- reject implicit signed/unsigned mixing unless a safe common representation is
  explicitly established;
- do not present integer Quantity division as generally exact arithmetic;
- do not rely on debug-mode traps as semantic protection;
- overflow policy must be explicit if integral arithmetic enters production.

### Floating Quantity arithmetic

Ordinary D promotion remains a viable candidate for `float`/`double`
combinations, subject to exact tests for result type, non-finite behavior,
CTFE, and attributes.

### Mixed integral/floating arithmetic

Potentially acceptable for scalar scaling because the result becomes floating,
but this still needs an explicit rule rather than accidental language promotion.

## Next experiment

R04.1 should now split into two focused probes:

1. floating same-Spec/scalar arithmetic, including NaN, infinity, signed zero,
   CTFE, and float/double promotion;
2. integral arithmetic policy candidates, comparing:
   - same-Rep only,
   - safe-widening-only,
   - explicit checked result API,
   - rejecting division except through an explicit conversion/rounding intent.

The goal is to avoid designing a large checked-arithmetic subsystem unless
consumer evidence requires it, while also avoiding undefined or surprising raw
integer semantics.
