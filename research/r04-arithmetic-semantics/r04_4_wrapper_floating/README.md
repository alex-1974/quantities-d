# R04.4 — Quantity wrapper floating arithmetic

This probe moves the accepted R04.3 floating behavior into a local
`Q!(Spec, Rep)` wrapper shaped like the production canonical-storage model.

It tests:

- same-Spec float/float and float/double addition;
- result Rep from `typeof(raw expression)`;
- scalar multiplication in both directions;
- scalar division;
- `@safe pure nothrow @nogc`;
- basic CTFE;
- infinity/NaN, signed zero, and overflow-to-infinity through the wrapper.

It intentionally does not modify production `Quantity` and does not decide
integral arithmetic.


## Observed baseline result — 2026-09-27

The wrapper probe passed on:

- DMD 2.111 x86_64 debug;
- DMD 2.111 x86_64 release;
- LDC 1.41 x86_64 debug;
- LDC 1.41 x86_64 release.

Observed semantic results were identical across those configurations:

- Q!(Length,float) + Q!(Length,float) -> Q!(Length,float);
- float/double mixed Quantity addition -> Q!(Length,double);
- double/float mixed Quantity addition -> Q!(Length,double);
- scalar multiplication with double -> Q!(Length,double);
- scalar division of double Quantity by float -> Q!(Length,double);
- infinity cancellation classified as NaN;
- -0 + -0 preserved a negative zero sign;
- double.max * 2.0 classified as infinity at runtime.

The compile-time attribute probe also succeeded under both baseline compilers,
demonstrating that the local wrapper implementation can remain:

`@safe pure nothrow @nogc`

while supporting basic CTFE.

Note: the runtime diagnostic text printed `typeof(ff.canonicalValue)`, which is
the member-function type rather than the stored Rep type. The compile-time
`static assert` checks are the normative evidence for ResultRep identity.

## R04.4 conclusion

For floating Rep arithmetic, a Quantity-shaped canonical-storage wrapper can use
the raw D expression type as ResultRep without introducing a quantities-specific
promotion lattice on the measured baseline.

This is sufficient semantic evidence to proceed to code-generation comparison.

It is not yet a zero-overhead claim. The next gate is to compare generated code
for raw scalar arithmetic against the equivalent Quantity wrapper operations in
release/optimized builds.
