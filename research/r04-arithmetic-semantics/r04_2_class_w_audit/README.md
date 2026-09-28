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
