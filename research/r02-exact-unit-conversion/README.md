# R02 — Exact unit representation and conversion

Research-only probe for quantities-d issue #2.

## First question

Can exact linear-unit definitions be represented and composed at compile time
without storing runtime unit metadata or prematurely converting scale factors to
floating point?

Reference units:

- metre: 1 m
- kilometre: 1000 m
- international foot: exactly 381/1250 m
- US survey foot: exactly 1200/3937 m

The first probe deliberately tests unit algebra only. Quantity representation,
integer/floating conversion, rounding and overflow policy remain subsequent
steps.

No code in this directory is proposed public API.
