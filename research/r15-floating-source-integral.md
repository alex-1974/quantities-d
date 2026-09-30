# R15 Probe 13 — represented floating sources to long

Status: represented-source wrapper validated on both baseline compilers; not promoted. Issue #42.

## Scope

The new research wrapper deduces float, double or trait-qualified real source
types and routes the exact represented source tuple into Probe 12's composed
Unit-scale integral kernel. Target is long. Checked intent has no payload for
inexact results; explicit rounded intent supplies the integer selected by
towardZero, floor, ceiling or nearestTiesAway. The conservative exact-unrounded
range candidate from Probe 12 remains unchanged and is not yet a production
mixed-Rep policy decision.

float/double reconstruction reads stored bits through Probe 10's narrowly
trusted memcpy helper. It neither widens the source through an intermediate
floating conversion nor recovers a source decimal spelling. Exponent fields
classify NaN (including signaling bit patterns) and both infinities as nonFinite
before any scale or integral range work. real uses finite checks and frexp/ldexp,
without reading its ABI layout. Supported traits are (64,-16381,16384) and
(53,-1021,1024). Signed floating zero becomes exact integral zero.

For real80 minSubnormal, frexp's normalized 64-bit mantissa has exponent -16508.
The bounded Probe 12 tuple entry expects a minimum exponent of -16445. The
wrapper removes trailing zero bits from the nonzero real significand while
incrementing the exponent; minSubnormal thereby becomes (1,-16445). This is an
exact change of tuple representation, not value rounding. No carrier widening
or source-format assumption is hidden in an integer cast.

This wrapper is a research function with explicit scale factors, not the final
named Quantity construction/extraction API. Unit template constraints,
invariant-owning result carriers, unsigned targets, public exact-required
operations and production integration remain outside this probe.

## Gates

The external runner passes sources using type deduction. A safe, pure, nothrow,
nogc consumer checks const float, immutable double and const qualified real.
Compile-negative assertions reject deduced long, ulong and string sources. An
ordinary double source conversion is rejected in CTFE because stored-source bit
reconstruction cannot execute there. The explicit tuple CTFE gate remains in
Probe 12; this does not claim arbitrary real-source CTFE qualification.

The independent Python Fraction oracle decodes stored float/double source bits,
constructs exact real test values, composes the rational Unit ratio and computes
range/status/integer rounding mathematically. Fixed cases cover signed zeros,
subnormals/minimum normals, extrema, both NaN signs and signaling bit patterns,
both infinities, positive/negative ties, long boundary neighbors, real80 exact
long.max and half-step boundaries, negative long.min Unit numerators, composed
wide factors and complete cancellation. real NaN/infinity are included explicitly.
Real test tuples are chosen to be exactly representable in the reported format;
the oracle never assumes an arbitrary real-producing expression was exact.
Seed 0x150013 adds 20,000 random cases. All earlier probes rerun in the matrix.

## Results

Tested code commit: `ba4cf1cf23c7b0dded005cf27257af56f66d1d7b`.
CI: https://github.com/alex-1974/quantities-d/actions/runs/36776805449.

DMD 2.111.0 and LDC 1.41.0 each passed 23,150 Probe 13 comparisons with zero
mismatches: 761 exact, 13,636 inexact, 8,068 overflow and 685 nonFinite.
The safe/pure/nothrow/nogc qualified-source consumers and compile-negative gates
passed. Both environments report real traits (64,-16381,16384), so this run
qualifies real80; the binary64-like real trait branch remains unqualified on a
matching platform. The smallest real80 subnormal works through the canonicalized
tuple path. Probes 10 (20,960), 11 (20,034) and 12 (20,560) also passed on each
compiler. These are default-build research results, not performance or release
qualification.

Next: an invariant-owning result carrier and named mixed-Rep API candidate with
actual Unit templates, construction/extraction symmetry and compile-negative
consumer gates. Decide the exact-unrounded range rule explicitly before any
production promotion. Research aggregates remain temporary scaffolding.
