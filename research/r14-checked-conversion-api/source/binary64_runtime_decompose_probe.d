module binary64_runtime_decompose_probe;

import core.stdc.string : memcpy;

struct Parts
{
    bool negative;
    ulong significand;
    int exponent2;
}

@safe pure nothrow @nogc
ulong binary64Bits(double value)
{
    ulong bits;
    () @trusted {
        memcpy(&bits, &value, double.sizeof);
    }();
    return bits;
}

@safe pure nothrow @nogc
Parts decomposeStoredBinary64(double value)
{
    const bits = binary64Bits(value);
    const negative = (bits >> 63) != 0;
    const exponentField = cast(uint)((bits >> 52) & 0x7ffUL);
    const fraction = bits & ((1UL << 52) - 1UL);

    if (exponentField == 0)
    {
        // Zero or subnormal: fraction * 2^-1074.
        return Parts(negative, fraction, -1074);
    }

    // Caller is responsible for excluding NaN and infinity.
    assert(exponentField != 0x7ff);

    // Normal: (2^52 + fraction) * 2^(biasedExponent - 1023 - 52).
    return Parts(
        negative,
        (1UL << 52) | fraction,
        cast(int) exponentField - 1023 - 52);
}

@safe unittest
{
    auto one = decomposeStoredBinary64(1.0);
    assert(!one.negative);
    assert(one.significand == 1UL << 52);
    assert(one.exponent2 == -52);

    auto tenth = decomposeStoredBinary64(0.1);
    assert(!tenth.negative);
    assert(tenth.significand == 7205759403792794UL);
    assert(tenth.exponent2 == -56);

    auto max = decomposeStoredBinary64(double.max);
    assert(!max.negative);
    assert(max.significand == (1UL << 53) - 1UL);
    assert(max.exponent2 == 971);

    const minSubnormal = double.min_normal * double.epsilon;
    auto sub = decomposeStoredBinary64(minSubnormal);
    assert(!sub.negative);
    assert(sub.significand == 1UL);
    assert(sub.exponent2 == -1074);

    auto negative = decomposeStoredBinary64(-1.5);
    assert(negative.negative);
    assert(negative.significand == 6755399441055744UL);
    assert(negative.exponent2 == -52);

    auto negativeZero = decomposeStoredBinary64(-0.0);
    assert(negativeZero.negative);
    assert(negativeZero.significand == 0UL);
    assert(negativeZero.exponent2 == -1074);
}
