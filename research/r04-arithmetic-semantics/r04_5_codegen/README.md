# R04.5 — Floating wrapper code-generation gate

## Goal

Test the zero-overhead hypothesis for the R04 floating arithmetic design.

This is a code-generation comparison, not a timing benchmark.

Each operation is exposed twice:

- raw scalar implementation;
- equivalent local Quantity-shaped wrapper implementation.

Pairs:

- rawAddFD / quantityAddFD
- rawScaleFD / quantityScaleFD
- rawDivDF / quantityDivDF

The functions use extern(C) and pragma(inline, false) so their generated bodies
can be inspected directly.

## Gate

For the measured compiler/version/architecture configuration, the Quantity form
should lower to the same essential floating instructions and should introduce no
wrapper storage, allocation, metadata access, or helper call that survives
optimization.

Byte-identical assembly is not required: register choice, labels, directives,
and scheduling may differ. The semantic instruction cost is the criterion.

Do not generalize results beyond the measured compiler/version/architecture.
