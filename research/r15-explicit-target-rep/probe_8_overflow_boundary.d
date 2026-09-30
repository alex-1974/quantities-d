module r15_probe_8_overflow_boundary;

import std.stdio : writeln;

import quantities.binary64_scale : scaleBinary64;
import quantities.floating_exact : rationalResultExactlyBinary64;

void main()
{
    enum long denominator = 1L << 62;
    enum long numerator = denominator + 1L;

    const scaled =
        scaleBinary64(
            double.max,
            numerator,
            denominator);

    writeln("scaleBinary64 overflow flag: ", scaled.overflow);
    writeln("scaled value == double.max: ", scaled.value == double.max);

    const exact =
        rationalResultExactlyBinary64(
            double.max,
            numerator,
            denominator);

    writeln("rational result exactly binary64: ", exact);

    // Mathematical exact result is:
    //
    // double.max * (1 + 2^-62)
    //
    // and therefore strictly larger than double.max even though its
    // nearest-even binary64 rounding may remain double.max.
    assert(numerator > denominator);
    assert(!exact);

    writeln(
        "R15 Probe 8 OBSERVE: mathematical-range overflow "
        ~ "boundary classified by current binary64 scale kernel");
}
