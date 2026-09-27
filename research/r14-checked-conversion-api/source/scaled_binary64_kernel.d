module scaled_binary64_kernel;

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
double scaleRational(double value, long numerator, long denominator)
{
    assert(denominator > 0);

    if (value == 0.0 || numerator == 0)
        return value * cast(double) numerator;

    const bool negative = (value < 0.0) != (numerator < 0);
    double x = value < 0.0 ? -value : value;

    int exponent;
    double mantissa = frexp(x, exponent);

    ulong n = magnitude(numerator);
    ulong d = cast(ulong) denominator;

    // Move powers of two from the exact rational into the binary exponent.
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

    // n and d are now odd. Their ratio is bounded independently from the
    // source exponent, so scale the normalized mantissa before restoring the
    // binary exponent. Choose operation order to keep the intermediate near
    // the normalized range.
    const double nf = cast(double) n;
    const double df = cast(double) d;
    double scaled;

    if (n <= d)
        scaled = (mantissa * nf) / df;
    else
        scaled = (mantissa / df) * nf;

    scaled = ldexp(scaled, exponent);
    return negative ? -scaled : scaled;
}

@safe unittest
{
    enum ordinary = scaleRational(1.5, 2, 3);
    static assert(ordinary == 1.0);

    enum avoidableOverflow = scaleRational(double.max, 2, 3);
    static assert(avoidableOverflow <= double.max);
    static assert(avoidableOverflow > 0.0);

    enum identityMax = scaleRational(double.max, 1, 1);
    static assert(identityMax == double.max);

    enum minimumNormal = scaleRational(double.min_normal, 3, 2);
    static assert(minimumNormal > 0.0);

    enum minimumSubnormal = double.min_normal * double.epsilon;
    enum subnormalIdentity = scaleRational(minimumSubnormal, 1, 1);
    static assert(subnormalIdentity == minimumSubnormal);

    enum negative = scaleRational(-1.5, 2, 3);
    static assert(negative == -1.0);

    // Large odd rational components should remain finite when the exact
    // result is finite and should not overflow merely because the scale
    // components are large.
    enum hugeOddBalanced = scaleRational(
        1.0,
        long.max,
        long.max - 2);
    static assert(hugeOddBalanced > 1.0);
    static assert(hugeOddBalanced < 2.0);

    // Powers of two are absorbed into the exponent exactly.
    enum powerOfTwoUp = scaleRational(1.5, 1024, 1);
    static assert(powerOfTwoUp == 1536.0);

    enum powerOfTwoDown = scaleRational(1536.0, 1, 1024);
    static assert(powerOfTwoDown == 1.5);

    // A true overflow must still overflow.
    enum trueOverflow = scaleRational(double.max, 2, 1);
    static assert(trueOverflow > double.max);

    // A true underflow may round to zero; this must not be mistaken for a
    // non-finite result.
    enum minimumSubnormalHalf =
        scaleRational(minimumSubnormal, 1, 2);
    static assert(minimumSubnormalHalf == 0.0);

    // Scaling a minimum subnormal upward by an exact power of two must recover
    // a representable non-zero value.
    enum minimumSubnormalUp =
        scaleRational(minimumSubnormal, 2, 1);
    static assert(minimumSubnormalUp > minimumSubnormal);

    // Check a halfway-style value where operation ordering could otherwise
    // expose double-rounding differences.
    enum oneThird = scaleRational(1.0, 1, 3);
    enum twoThirds = scaleRational(1.0, 2, 3);
    static assert(oneThird > 0.0);
    static assert(twoThirds > oneThird);

    assert(scaleRational(double.max, 2, 3) <= double.max);
}
