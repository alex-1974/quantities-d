# Private exact-conversion qualification

P1 introduces `quantities.exact_conversion` as a package-only implementation.
The existing public conversions and package exports are unchanged. ADR 0012
is still proposed in PR #50; exposing the six target-Rep APIs is a separate P2
review. This work contributes to #42 without closing it.

The kernel composes represented Source significand and both Unit ratios with
cross-cancellation. Its private 192-bit numerator and denominator cover the
190/126-bit bounds. The binary exponent remains separate. Closed-range checks
precede integral rounding or one nearest-even float/double quantization.
Ordinary floating Source/Target calls explicitly reject CTFE; long/ulong to
long remain CTFE capable. No research D module is imported or compiled.

Existing binary64 helpers have a 64-bit denominator. The real arithmetic
helpers support wider ratios but use arithmetic range behavior and lack the
conversion exactness/status contract. They remain unchanged; extracting a
shared arithmetic workspace is outside this promotion.

Run after checking out research files at commit
`c4e752d9d47acb962cbd77f302198c9e0ea34551`:

```sh
bash tests/exact-conversion/run.sh dmd /path/to/pinned/research
```

`prepare.py` adapts only runner imports/names and removes the research-only
width diagnostic. Three independent Python Fraction corpora check tuple
float/double quantization, tuple integral rounding, and represented floating
sources to long. A fourth corpus checks represented long/ulong/float/double/
qualified real to float/double, including zero signs, subnormals, non-finite
inputs, large ratios, and full-width magnitudes. Each runs in debug, release,
and optimized builds (bounds checks on for optimized), on DMD 2.111.0 and LDC
1.41.0. Module unit tests cover attributes, CTFE, constraints, and selected
boundary laws; an external consumer checks package visibility.

Native binary80 `real` is exercised on the current Linux runners. A platform
with binary64-like `real` needs its own native qualification before claiming
that platform is covered. This gate is correctness evidence, not performance
or release qualification.
