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


## Observed native matrix — DMD 2.111 / LDC 1.41, x86_64

Both baseline compilers produced the same native ResultRep matrix:

| A | B | + / - / * native ResultRep |
|---|---|---|
| byte | byte | int |
| ubyte | ubyte | int |
| byte | ubyte | int |
| short | short | int |
| ushort | ushort | int |
| short | ushort | int |
| int | int | int |
| uint | uint | uint |
| int | uint | uint |
| long | long | long |
| ulong | ulong | ulong |
| long | ulong | ulong |
| int | long | long |
| uint | long | long |
| int | ulong | ulong |
| uint | ulong | ulong |

The result confirms the earlier boundary observations.

### Useful native cases

D's integral promotions provide a comfortably wider signed result for the
narrow integer families:

- byte/byte -> int;
- ubyte/ubyte -> int;
- byte/ubyte -> int;
- short/short -> int;
- ushort/ushort -> int;
- short/ushort -> int.

These native results are operand-safe and, for addition/subtraction of the
listed narrow types, also provide substantial result headroom.

### Problem boundary

At 32 bits and above, native promotion is not a sufficient quantities-d policy:

- int + uint -> uint;
- long + ulong -> ulong;
- int + ulong -> ulong.

Negative values from the signed operand are not representable in those result
types.

The compilers agree here, so this is language promotion behavior rather than a
DMD/LDC disagreement.

## Consequence

R04 should not use `typeof(a op b)` as the general integral ResultRep rule.

The next candidate to evaluate is an operand-safe common built-in type selected
from value ranges rather than D's arithmetic conversion rules.

That trait must be tested independently from overflow policy.
