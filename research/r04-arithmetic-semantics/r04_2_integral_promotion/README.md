# R04.2.8 — Integral Quantity promotion gate

## Goal

Apply the exact R04.2.7 operation-safe ResultRep model to a Quantity-shaped
wrapper and test the semantics that would matter for production promotion.

This is still research-local code.

## Gates

### Same-Spec arithmetic

- Quantity + Quantity uses AddRep.
- Quantity - Quantity uses SubRep.
- result Spec remains unchanged.
- exact boundary values are preserved.

### Integral scalar multiplication

- Quantity * scalar uses MulRep.
- scalar * Quantity is symmetric in result type and value.

### Class O

When no built-in type contains the complete mathematical result range, the
plain operator is unavailable at compile time.

### Attributes and CTFE

Admitted operations must remain:

- @safe;
- pure;
- nothrow;
- @nogc;
- CTFE-capable.

### Boundary emphasis

The probe exercises signed minima/maxima and unsigned maxima, not merely small
example values.

Passing this gate establishes semantic suitability of the exact traits in a
Quantity-shaped API. Code-generation equivalence remains a separate next gate.


## Observed promotion result

The complete promotion gate passed on the baseline matrix:

- DMD 2.111 debug: pass;
- DMD 2.111 release: pass;
- LDC 1.41 debug: pass;
- LDC 1.41 release: pass.

All runs exited with status 0.

Therefore the R04.2.7 ResultRep model survives promotion into a
Quantity-shaped operator API for the tested semantics:

- exact widened boundary arithmetic;
- signed and unsigned result ranges;
- symmetric integral scalar multiplication;
- compile-time rejection of tested Class-O expressions;
- CTFE;
- @safe pure nothrow @nogc.

No runtime overflow machinery is required for admitted Class-W operators.

The remaining promotion gate is optimized code generation versus equivalent
raw arithmetic with explicit widening.
