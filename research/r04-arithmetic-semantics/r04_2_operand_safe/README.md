# R04.2.2 — Operand-safe common integral Rep

This probe selects the smallest normal D integral type whose value range
contains the complete value ranges of both operand Reps.

It does not claim that the selected type can contain every result of addition,
subtraction, or multiplication.

A result of `void` means that no normal built-in D integer type can represent
both complete operand ranges.

Expected boundary examples:

- byte + ubyte operand ranges -> short;
- short + ushort operand ranges -> int;
- int + uint operand ranges -> long;
- uint + long operand ranges -> long;
- long + ulong -> no built-in common Rep;
- int + ulong -> no built-in common Rep.

The trait is deliberately research-local. It is not production API.


## Observed result — DMD 2.111 / LDC 1.41, x86_64

Both compilers produced the same operand-safe common Rep matrix:

| A | B | OperandSafeCommon |
|---|---|---|
| byte | byte | byte |
| ubyte | ubyte | ubyte |
| byte | ubyte | short |
| short | short | short |
| ushort | ushort | ushort |
| short | ushort | int |
| int | int | int |
| uint | uint | uint |
| int | uint | long |
| long | long | long |
| ulong | ulong | ulong |
| long | ulong | void |
| int | long | long |
| uint | long | long |
| int | ulong | void |
| uint | ulong | ulong |

The symmetry assertions passed for all tested pairs.

## R04.2.2 conclusion

The value-range-based common Rep rule is simple, deterministic, compiler-neutral
on the measured baseline, and fixes the signed/unsigned reinterpretation problem
present in D's native promotion rules.

Important boundary outcomes:

- int/uint -> long;
- uint/long -> long;
- long/ulong -> no built-in common Rep;
- int/ulong -> no built-in common Rep.

This trait solves only operand representation.

It deliberately does not claim that the selected Rep can hold every
mathematical result of addition, subtraction, or multiplication.

Therefore the next R04.2 decision is overflow policy, not further ResultRep
promotion complexity.

Provisional research direction:

- use operand-safe ResultRep as the default candidate where one exists;
- reject or require explicit handling where no built-in operand-safe Rep exists;
- keep overflow detection/result semantics orthogonal to Rep selection.
