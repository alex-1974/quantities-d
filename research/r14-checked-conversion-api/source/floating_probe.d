module floating_probe;

import common : ConversionResult, ConversionStatus;
import floating_exact : rationalResultExactlyBinary64;

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

    const status =
        rationalResultExactlyBinary64(value, numerator, denominator)
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
    static assert(decimalLike.status == ConversionStatus.inexact);
    static assert(decimalLike.value > 0.0);

    enum representedTenth = convertFloating(0.1, 10, 1);
    static assert(representedTenth.status == ConversionStatus.inexact);
    static assert(representedTenth.value == 1.0);

    enum overflow = convertFloating(double.max, 2, 1);
    static assert(overflow.status == ConversionStatus.overflow);
}
