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
