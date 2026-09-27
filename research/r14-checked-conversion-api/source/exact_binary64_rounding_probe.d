module exact_binary64_rounding_probe;

import std.math : frexp, ldexp;

private:
struct Binary64Exact
{
    bool negative;
    ulong significand;
    int exponent2;
}

@safe pure nothrow @nogc
Binary64Exact decompose(double value)
{
    assert(value == value);
    assert(value <= double.max && value >= -double.max);

    if (value == 0.0)
        return Binary64Exact(false, 0, 0);

    const bool negative = value < 0.0;
    double x = negative ? -value : value;

    int exponent;
    double fraction = frexp(x, exponent);

    // Binary64 has at most 53 significant bits. Scale the fraction so the
    // represented significand becomes an integer exactly.
    ulong significand = cast(ulong) ldexp(fraction, 53);
    int exponent2 = exponent - 53;

    // Remove powers of two to keep the integer payload compact.
    while (significand != 0 && (significand & 1UL) == 0)
    {
        significand >>= 1;
        ++exponent2;
    }

    return Binary64Exact(negative, significand, exponent2);
}

@safe pure nothrow @nogc
int bitLength(ulong value)
{
    int bits;
    while (value != 0)
    {
        ++bits;
        value >>= 1;
    }
    return bits;
}

struct RoundedInteger
{
    ulong value;
    bool inexact;
}

@safe pure nothrow @nogc
RoundedInteger shiftRightRoundNearestEven(ulong value, int shift)
{
    assert(shift >= 0);

    if (shift == 0)
        return RoundedInteger(value, false);

    if (shift >= 64)
        return RoundedInteger(0, value != 0);

    const ulong lowerMask = (1UL << shift) - 1UL;
    const ulong remainder = value & lowerMask;
    ulong upper = value >> shift;

    const ulong halfway = 1UL << (shift - 1);
    bool roundUp = remainder > halfway
        || (remainder == halfway && (upper & 1UL) != 0);

    if (roundUp)
        ++upper;

    return RoundedInteger(upper, remainder != 0);
}

@safe pure nothrow @nogc
double rebuild(bool negative, ulong significand, int exponent2)
{
    double value = ldexp(cast(double) significand, exponent2);
    return negative ? -value : value;
}

@safe unittest
{
    enum one = decompose(1.0);
    static assert(one.significand == 1);
    static assert(one.exponent2 == 0);

    enum oneAndHalf = decompose(1.5);
    static assert(
        rebuild(oneAndHalf.negative,
                oneAndHalf.significand,
                oneAndHalf.exponent2)
        == 1.5);

    enum maximum = decompose(double.max);
    static assert(
        rebuild(maximum.negative,
                maximum.significand,
                maximum.exponent2)
        == double.max);

    enum minNormal = decompose(double.min_normal);
    static assert(
        rebuild(minNormal.negative,
                minNormal.significand,
                minNormal.exponent2)
        == double.min_normal);

    enum minSubnormalValue =
        double.min_normal * double.epsilon;
    enum minSubnormal = decompose(minSubnormalValue);
    static assert(minSubnormal.significand == 1);
    static assert(minSubnormal.exponent2 == -1074);

    enum negative = decompose(-1.5);
    static assert(
        rebuild(negative.negative,
                negative.significand,
                negative.exponent2)
        == -1.5);

    // Basic 53-bit rounding behavior.
    enum exact53 =
        shiftRightRoundNearestEven((1UL << 53) - 1, 0);
    static assert(!exact53.inexact);

    enum tieDown =
        shiftRightRoundNearestEven(5, 1);
    static assert(tieDown.value == 2);

    enum tieUp =
        shiftRightRoundNearestEven(7, 1);
    static assert(tieUp.value == 4);

    // Runtime parity checks.
    const runtimeMax = decompose(double.max);
    assert(rebuild(runtimeMax.negative,
                   runtimeMax.significand,
                   runtimeMax.exponent2)
        == double.max);

    const runtimeMinSubnormal = decompose(
        double.min_normal * double.epsilon);
    assert(runtimeMinSubnormal.significand == 1);
    assert(runtimeMinSubnormal.exponent2 == -1074);
}
