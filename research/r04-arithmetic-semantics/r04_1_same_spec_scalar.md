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
