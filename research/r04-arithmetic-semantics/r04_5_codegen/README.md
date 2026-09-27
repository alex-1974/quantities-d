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


## Measured result — x86_64 optimized release

### DMD 2.111

For all three pairs, the Quantity wrapper introduced no surviving wrapper
storage, metadata access, allocation, or helper call.

- add: both forms lower to float-to-double conversion plus scalar double add;
- scale: both forms lower to float-to-double conversion plus scalar double multiply;
- divide: both forms lower to float-to-double conversion plus scalar double divide.

The exact instruction sequences are not byte-identical in every DMD pair.
Register selection and spill/reload behavior differ; notably the Quantity
division form was shorter than the raw comparison. This is not treated as a
Quantity performance advantage. The relevant result is that no Quantity
abstraction cost survives.

### LDC 1.41

The relevant function bodies were instruction-identical for every pair:

```text
rawAddFD / quantityAddFD:
    cvtss2sd
    addsd

rawScaleFD / quantityScaleFD:
    cvtss2sd
    mulsd

rawDivDF / quantityDivDF:
    cvtss2sd
    divsd
```

No wrapper storage, metadata operation, allocation, or helper call survives.

## R04.5 conclusion

The zero-overhead gate passes for the tested R04 floating operations on the
measured baseline:

- x86_64;
- DMD 2.111 optimized release;
- LDC 1.41 optimized release.

Within this scope, the Quantity-shaped wrapper has the same essential
floating-point instruction cost as the raw scalar implementation.

This result supports using the D-native floating ResultRep rule established by
R04.4 without adding a quantities-specific promotion mechanism.

The result is deliberately scoped. It is not a claim for every operation,
compiler version, optimization mode, operating system, or architecture.
Future compiler/version/architecture-specific paths remain evidence-driven
under PORTABILITY.md.
