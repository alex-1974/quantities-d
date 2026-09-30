module r15_probe_7_target_direct_rounding;

import core.stdc.string : memcpy;
import std.stdio : writeln;

import quantities.binary64_scale : scaleBinary64;

private uint bitsOf(float value)
{
    uint bits;
    memcpy(&bits, &value, float.sizeof);
    return bits;
}

void main()
{
    // Exact unit factor:
    //
    //     1 + 2^-24 + 2^-60
    //
    // applied to an exactly represented double source 1.0.
    //
    // The exact mathematical target is just above the midpoint between 1.0f
    // and the next binary32 value, so direct once-rounding to float must choose
    // the upper neighbor.
    //
    // Correct binary64 rounding first loses 2^-60, lands exactly at the
    // binary32 midpoint, and a subsequent float cast tie-to-even rounds down.
    enum long denominator = 1L << 60;
    enum long numerator =
        denominator
        + (1L << 36)
        + 1L;

    const scaled64 =
        scaleBinary64(
            1.0,
            numerator,
            denominator);

    assert(!scaled64.overflow);

    const float viaBinary64 =
        cast(float)scaled64.value;

    const float directExpected =
        1.0f + float.epsilon;

    writeln("via binary64 bits: ", bitsOf(viaBinary64));
    writeln("direct target bits:", bitsOf(directExpected));

    assert(bitsOf(viaBinary64) == 0x3f80_0000U);
    assert(bitsOf(directExpected) == 0x3f80_0001U);

    writeln(
        "R15 Probe 7 PASS: nontrivial mixed-Rep conversion "
        ~ "must quantize directly to TargetRep");
}
