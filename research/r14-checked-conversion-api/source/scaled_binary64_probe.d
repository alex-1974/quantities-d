module scaled_binary64_probe;

import std.math : frexp, ldexp;

@safe pure nothrow @nogc
double roundTrip(double value)
{
    int exponent;
    const mantissa = frexp(value, exponent);
    return ldexp(mantissa, exponent);
}

@safe unittest
{
    enum ordinary = roundTrip(1.5);
    static assert(ordinary == 1.5);

    enum maximum = roundTrip(double.max);
    static assert(maximum == double.max);

    enum minimumNormal = roundTrip(double.min_normal);
    static assert(minimumNormal == double.min_normal);

    enum minimumSubnormal =
        roundTrip(double.min_normal * double.epsilon);
    static assert(minimumSubnormal > 0.0);

    assert(roundTrip(1.5) == 1.5);
    assert(roundTrip(double.max) == double.max);
    assert(roundTrip(double.min_normal) == double.min_normal);
}
