# R15 Probe 12 — exact rational source to long with explicit rounding

Status: research candidate; validation pending. Issue #42.

## Scope and policy

The kernel accepts an explicit finite source tuple `significand * 2^exponent`
and exact composed From/To Unit scale factors from Probe 11. It targets `long`
and covers checked intent plus the four ADR 0007 rounding modes: towardZero,
floor, ceiling, nearestTiesAway. Source significands span unsigned 64 bits;
exponents are bounded to [-16445, 16383], covering qualified binary32,
binary64 and real80 source decompositions. This is a tuple-kernel probe, not a
floating-source wrapper, actual Unit-template integration, or a nonFinite test.

**Candidate boundary rule:** compare the exact unrounded result against
`[long.min, long.max]` before selecting rounding. Out-of-range values report
overflow with no payload, even if towardZero could return a boundary integer.
An in-range fraction is inexact; checked intent has no payload, while explicit
rounded intent supplies the selected rounded integer. Integral signed zero is 0.
Exact integers have exact status and a payload under every intent.

ADR 0005/0007 require explicit rounding and distinct overflow but do not freeze
mixed-Rep boundary policy. This probe adopts the conservative unrounded range
rule consistently with the floating conversion range rule. Promotion must
explicitly decide and document it; these tests establish this candidate only.
They do not qualify an alternative rule that checks only the rounded result.

## Bounded algorithm

The shared Probe 11 private six-limb 192-bit carrier retains the fully reduced
composed numerator (up to 190 bits) and denominator (up to 126 bits). The
exponent stays separate. A bit-length-aware exact comparison checks the signed
range and finds floor of the magnitude using at most 64 binary-search steps.
Each denominator times a trial magnitude fits at most 189 bits. Equal-width
comparison shifts align only bounded carriers, avoiding enormous shifts for
real80 exponents. Zero comparisons are handled separately.

Exactness uses equality of the original rational and the integer floor.
NearestTiesAway compares twice the rational against denominator*(2*floor+1),
without a floating intermediate or remainder approximation. Inexact in-range
floor is strictly below the signed magnitude bound, so this odd multiplier fits
ulong and its product fits 190 bits. Directed rounding follows the combined
source/Unit sign. Reconstruction handles long.min without signed abs overflow.

The research aggregate is provisional and does not own production result
invariants. Its hasValue is verified by the runner; it must not be promoted as
the public result API. Research rounding enum uses ADR names but does not add a
production API. Existing floating probes are rerun because the shared research
module gains the integral entry point.

## Validation design

An independent Python Fraction oracle constructs the exact rational, applies
the candidate range rule, then computes integer rounding with signed integer
division. Fixed cases exercise long.min/max, half and quarter neighbors,
positive/negative ties, signed zero, extreme exponents, negative long.min Unit
numerators, complete cancellation and the 190/126-bit composed witness.
Seed 0x150012 adds 20,000 randomized cases. Checked fractional/overflow output
must omit payload. The external runner compiles and calls an
@safe pure nothrow @nogc consumer; a compile-time tuple conversion additionally
checks exact long.min. This limited CTFE check does not establish arbitrary
floating-source CTFE, complete CTFE policy coverage, performance, or compiler
cost. Unsigned targets and public mixed-Rep API integration remain outside scope.

## Results

Pending DMD 2.111.0 and LDC 1.41.0 CI comparison.
