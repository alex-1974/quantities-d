# R04.2.6 — Exhaustive Class-W trait audit

Compare the current bit-width Class-W candidate against exact mathematical
result ranges for every ordered pair of D built-in integer Reps:

byte, ubyte, short, ushort, int, uint, long, ulong.

The exact reference uses BigInt only in the research executable.

For each ordered pair the probe compares:

- addition;
- subtraction;
- multiplication.

Any line before the final summary is a mismatch between the candidate trait and
the smallest exact operation-safe built-in Rep.

This audit intentionally includes 64-bit pairs: the current candidate rejects
them as Class O, while the exact reference determines whether that rejection is
necessary for each concrete type combination.

The goal is to discover both:
- unsafe candidate results;
- unnecessarily wide or unnecessarily rejected results.

The final production trait may prefer a deliberate canonical widening rule over
the mathematically smallest type, but such differences must be explicit rather
than accidental.


## Observed result — DMD 2.111 / LDC 1.41, x86_64

Both compilers produced the same audit output.

The probe checked 64 ordered Rep pairs and 192 operation cases.

There were 25 candidate/reference mismatches. Every mismatch was a conservative
over-widening of an all-unsigned operand pair. No mismatch selected a type
narrower than the exact mathematical range.

Representative cases:

- ubyte + ubyte: candidate ushort, exact smallest short;
- ubyte - ubyte: candidate ushort, exact smallest short;
- ushort + ushort: candidate uint, exact smallest int;
- uint + uint: candidate ulong, exact smallest long;
- uint - uint: candidate ulong, exact smallest long;
- ubyte * ushort: candidate uint, exact smallest int;
- uint * ushort: candidate ulong, exact smallest long.

The audit therefore found two distinct issues.

### 1. Signed result types can be the smallest safe type for unsigned inputs

A non-negative mathematical result does not imply that the smallest containing
built-in type should be unsigned.

For example, uint + uint has range 0 .. 2^33-2. long contains that complete
range and is the smallest normal built-in type that does so.

Likewise ubyte * ushort fits int even though both operands are unsigned.

The current candidate's rule "unsigned inputs -> unsigned ResultRep" is safe but
unnecessarily wide.

### 2. Subtraction needs its own signedness rule

Unsigned subtraction can produce negative mathematical results.

Therefore CandidateSub cannot be an alias of CandidateAdd.

Examples:

- ubyte - ubyte requires -255 .. 255 -> short;
- ushort - ushort requires int;
- uint - uint requires long.

A final SubRep must derive its range independently.

## Revised direction

Do not derive the final operation-safe ResultRep from result signedness first.

Instead derive the mathematical result-range requirements for each operation,
then select the smallest supported built-in integer type containing that range.

The production implementation should achieve this without BigInt and without
performing potentially overflowing compile-time endpoint arithmetic.

A bit-width/signedness trait remains viable, but AddRep, SubRep, and MulRep need
operation-specific formulas.

The current R04.2.5 trait remains proven safe for the tested matrix, but it is
not the final minimal ResultRep policy.
