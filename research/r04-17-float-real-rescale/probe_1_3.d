module r04_17_probe_1_3;

import std.stdio : writeln;
import quantities.binary64_scale : rescaleProductBinary64;

private void printProps(T)(string name)
{
    writeln(
        name,
        ": sizeof=", T.sizeof,
        " alignof=", T.alignof,
        " mant_dig=", T.mant_dig,
        " min_exp=", T.min_exp,
        " max_exp=", T.max_exp);
}

void main()
{
    version (DigitalMars)
        writeln("compiler=dmd");
    else version (LDC)
        writeln("compiler=ldc");
    else
        writeln("compiler=other");

    writeln("pointer.sizeof=", (void*).sizeof);

    printProps!float("float");
    printProps!double("double");
    printProps!real("real");

    enum floatSignificandBits = float.mant_dig;
    enum exactRatioMagnitudeBits = 63;

    enum productNumeratorBits =
        floatSignificandBits
        + floatSignificandBits
        + exactRatioMagnitudeBits;

    enum quotientNumeratorBits =
        floatSignificandBits
        + exactRatioMagnitudeBits;

    enum quotientDenominatorBits =
        floatSignificandBits
        + exactRatioMagnitudeBits;

    static assert(productNumeratorBits == 111);
    static assert(quotientNumeratorBits == 87);
    static assert(quotientDenominatorBits == 87);
    static assert(productNumeratorBits <= 128);
    static assert(quotientNumeratorBits <= 128);
    static assert(quotientDenominatorBits <= 128);

    writeln(
        "binary32 structural bounds: product numerator <= ",
        productNumeratorBits,
        " bits, quotient numerator/denominator <= ",
        quotientNumeratorBits,
        "/",
        quotientDenominatorBits,
        " bits");

    // Exact scale:
    //
    //   n / d = 1 + 2^-24 + 2^-60
    //
    // The exact value lies just above the midpoint between 1.0f and the next
    // binary32 number. Correct once-rounded binary32 therefore selects the
    // upper float.
    //
    // Correctly rounding the exact expression first to binary64 loses 2^-60
    // and lands exactly on the binary32 midpoint. A subsequent float cast then
    // tie-to-even rounds down to 1.0f.
    enum long d = 1L << 60;
    enum long n = d + (1L << 36) + 1L;

    const double viaBinary64 =
        rescaleProductBinary64(
            1.0,
            1.0,
            n,
            d);

    const float doubleRounded =
        cast(float)viaBinary64;

    const float expectedOnceRounded =
        1.0f + float.epsilon;

    writeln("double-rounding probe:");
    writeln("  binary64 intermediate = ", viaBinary64.hexString);
    writeln("  cast-to-float result  = ", doubleRounded.hexString);
    writeln("  once-rounded expected = ", expectedOnceRounded.hexString);

    assert(viaBinary64 == 1.0 + 0x1p-24);
    assert(doubleRounded == 1.0f);
    assert(expectedOnceRounded > 1.0f);
    assert(doubleRounded != expectedOnceRounded);

    writeln("R04.17 Probe 1 PASS: format/property matrix emitted");
    writeln("R04.17 Probe 2 PASS: binary32 exact-width bounds fit 128 bits");
    writeln("R04.17 Probe 3 PASS: binary64-then-float route double-rounds incorrectly");
}
