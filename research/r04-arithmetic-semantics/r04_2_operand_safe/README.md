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
