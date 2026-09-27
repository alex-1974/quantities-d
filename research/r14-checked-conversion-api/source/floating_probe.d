module floating_probe;

import common : ConversionResult, ConversionStatus;

private:
@safe pure nothrow @nogc
bool finite(double value)
{
    // NaN is the only floating value unequal to itself.
    if (value != value)
        return false;

    // On the baseline compilers, double.max is finite and comparisons against
    // infinities classify them outside this range.
    return value <= double.max && value >= -double.max;
}

public:
@safe pure nothrow @nogc
ConversionResult!double convertFloating(
    double value,
    long numerator,
    long denominator)
{
    assert(denominator != 0);

    if (!finite(value))
        return ConversionResult!double(0.0, ConversionStatus.overflow);

    const double scaled =
        (value * cast(double) numerator) / cast(double) denominator;

    if (!finite(scaled))
        return ConversionResult!double(0.0, ConversionStatus.overflow);

    // Research criterion: reverse the exact rational operation in floating
    // arithmetic and compare to the represented source value. This is only a
    // probe; it is not yet accepted as the production exactness test.
    const double reversed =
        (scaled * cast(double) denominator) / cast(double) numerator;

    const status =
        reversed == value
            ? ConversionStatus.exact
            : ConversionStatus.inexact;

    return ConversionResult!double(scaled, status);
}

@safe unittest
{
    enum identity = convertFloating(1.5, 1, 1);
    static assert(identity.status == ConversionStatus.exact);
    static assert(identity.value == 1.5);

    enum binaryExact = convertFloating(1.5, 2, 1);
    static assert(binaryExact.status == ConversionStatus.exact);
    static assert(binaryExact.value == 3.0);

    enum binaryHalf = convertFloating(3.0, 1, 2);
    static assert(binaryHalf.status == ConversionStatus.exact);
    static assert(binaryHalf.value == 1.5);

    enum decimalLike = convertFloating(1.0, 1, 10);
    static assert(decimalLike.value > 0.0);

    enum overflow = convertFloating(double.max, 2, 1);
    static assert(overflow.status == ConversionStatus.overflow);
}
