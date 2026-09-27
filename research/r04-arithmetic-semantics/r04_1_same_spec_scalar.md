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
