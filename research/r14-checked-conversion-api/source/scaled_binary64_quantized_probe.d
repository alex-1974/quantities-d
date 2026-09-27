module scaled_binary64_quantized_probe;

import std.math : frexp, ldexp;

private:
@safe pure nothrow @nogc
ulong magnitude(long value)
{
    return value >= 0
        ? cast(ulong) value
        : cast(ulong)(-(value + 1)) + 1UL;
}

@safe pure nothrow @nogc
double quantizeBinary64(double value)
{
    if (value == 0.0)
        return value;

    const bool negative = value < 0.0;
    double x = negative ? -value : value;

    if (!(x <= double.max))
        return value;

    int exponent;
    frexp(x, exponent);

    if (exponent > -1022)
        return value;

    enum int minQuantumExponent = -1074;
    double quanta = ldexp(x, -minQuantumExponent);

    ulong lower = cast(ulong) quanta;
    const double remainder = quanta - cast(double) lower;

    if (remainder > 0.5
        || (remainder == 0.5 && (lower & 1UL) != 0))
        ++lower;

    const double rounded =
        ldexp(cast(double) lower, minQuantumExponent);
    return negative ? -rounded : rounded;
}

@safe pure nothrow @nogc
double scaleRationalBinary64(
    double value,
    long numerator,
    long denominator)
{
    assert(denominator > 0);

    if (value == 0.0 || numerator == 0)
        return quantizeBinary64(
            value * cast(double) numerator);

    const bool negative = (value < 0.0) != (numerator < 0);
    double x = value < 0.0 ? -value : value;

    int exponent;
    double mantissa = frexp(x, exponent);

    ulong n = magnitude(numerator);
    ulong d = cast(ulong) denominator;

    while ((n & 1UL) == 0)
    {
        n >>= 1;
        ++exponent;
    }

    while ((d & 1UL) == 0)
    {
        d >>= 1;
        --exponent;
    }

    const double nf = cast(double) n;
    const double df = cast(double) d;

    double scaled = n <= d
        ? (mantissa * nf) / df
        : (mantissa / df) * nf;

    scaled = ldexp(scaled, exponent);
    scaled = negative ? -scaled : scaled;

    return quantizeBinary64(scaled);
}

@safe unittest
{
    enum minSubnormal =
        double.min_normal * double.epsilon;

    enum avoidableOverflow =
        scaleRationalBinary64(double.max, 2, 3);
    static assert(avoidableOverflow > 0.0);
    static assert(avoidableOverflow <= double.max);

    enum trueOverflow =
        scaleRationalBinary64(double.max, 2, 1);
    static assert(trueOverflow > double.max);

    enum halfMin =
        scaleRationalBinary64(minSubnormal, 1, 2);
    static assert(halfMin == 0.0);

    enum oneAndHalfMin =
        scaleRationalBinary64(minSubnormal, 3, 2);
    static assert(oneAndHalfMin == minSubnormal * 2.0);

    enum twoAndHalfMin =
        scaleRationalBinary64(minSubnormal, 5, 2);
    static assert(twoAndHalfMin == minSubnormal * 2.0);

    enum exactIdentity =
        scaleRationalBinary64(minSubnormal, 1, 1);
    static assert(exactIdentity == minSubnormal);

    enum ordinary =
        scaleRationalBinary64(1.5, 2, 3);
    static assert(ordinary == 1.0);

    enum hugeOddBalanced =
        scaleRationalBinary64(
            1.0,
            long.max,
            long.max - 2);
    static assert(hugeOddBalanced > 1.0);
    static assert(hugeOddBalanced < 2.0);

    const runtimeMinSubnormal =
        double.min_normal * double.epsilon;

    assert(scaleRationalBinary64(
        runtimeMinSubnormal, 1, 2) == 0.0);

    assert(scaleRationalBinary64(
        runtimeMinSubnormal, 3, 2)
        == runtimeMinSubnormal * 2.0);

    assert(scaleRationalBinary64(
        double.max, 2, 3) <= double.max);
}
