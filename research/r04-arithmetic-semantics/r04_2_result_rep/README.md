# R04.2.1 — Integral ResultRep matrix

## Question

Can I1 (same-Spec + / -) and I2 (Quantity * integral scalar) use a simple,
predictable ResultRep rule without silently inheriting D's unsafe
signed/unsigned behavior?

## Two different requirements

### Operand-safe common type

A type is operand-safe when every value representable by either operand type is
also representable by the candidate result type.

This prevents the immediate `int + uint -> uint` problem where negative int
values are not representable in the native D result type.

### Operation-safe result type

A type is operation-safe when every mathematical result of the operation is
representable.

This is stronger.

Examples:

- byte + byte can fit in short, although D promotes the operands to int;
- int + int needs at least one extra signed value bit;
- long + long cannot be made universally overflow-free using the normal built-in
  fixed-width integer types;
- multiplication generally needs the sum of operand value widths.

Therefore ResultRep selection and overflow policy cannot be collapsed into one
rule.

## Candidate ResultRep policies

### A — native D expression type

Rejected as the complete integral policy by R04.1.

### B — operand-safe common built-in type

Choose the smallest built-in integral type that represents the full value range
of both operands.

Advantages:

- predictable;
- removes signed/unsigned reinterpretation at the operand boundary;
- often avoids unnecessary widening.

Limitation:

It does not guarantee that +, -, or * cannot overflow.

### C — operation-safe built-in type

Choose a built-in type large enough for the complete mathematical result range.

Advantage:

Operations within the admitted matrix need no runtime overflow handling.

Limitation:

No such normal built-in type exists for important combinations near the widest
supported Rep. Multiplication reaches this boundary even sooner.

### D — widened intermediate plus explicit final policy

Compute in a wider internal integer where available, then apply an explicit
overflow/result policy.

Potentially useful, but must not turn quantities-d into a general arbitrary
precision or checked-integer subsystem.

## Probe goal

Record D native result types and compare them with operand-safe/common-width
expectations for signed/unsigned and narrow/wide combinations.

No production policy is selected by this probe.
