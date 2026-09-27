module checked_kernel;

import common : ConversionResult, ConversionStatus, RoundingMode;

private:
@safe pure nothrow @nogc
ulong magnitude(long value)
{
    if (value >= 0)
        return cast(ulong) value;
    return cast(ulong)(-(value + 1)) + 1UL;
}

@safe pure nothrow @nogc
ulong gcd(ulong a, ulong b)
{
    while (b != 0)
    {
        const r = a % b;
        a = b;
        b = r;
    }
    return a;
}

struct Ratio
{
    long numerator;
    long denominator;
}

@safe pure nothrow @nogc
Ratio reduce(long numerator, long denominator)
{
    assert(denominator != 0);

    const bool negative = (numerator < 0) != (denominator < 0);
    ulong n = magnitude(numerator);
    ulong d = magnitude(denominator);
    const g = gcd(n, d);
    n /= g;
    d /= g;

    assert(d <= cast(ulong) long.max);
    const long signedN =
        negative
            ? (n == cast(ulong) long.max + 1UL ? long.min : -cast(long) n)
            : cast(long) n;

    return Ratio(signedN, cast(long) d);
}

@safe pure nothrow @nogc
bool multiplyChecked(long a, long b, out long result)
{
    static if (__traits(compiles, __builtin_mul_overflow(a, b, result)))
    {
        return !__builtin_mul_overflow(a, b, result);
    }
    else
    {
        // Portable research fallback for supported signed-long domain.
        if (a == 0 || b == 0)
        {
            result = 0;
            return true;
        }

        if (a == long.min)
        {
            if (b == 1) { result = long.min; return true; }
            return false;
        }
        if (b == long.min)
        {
            if (a == 1) { result = long.min; return true; }
            return false;
        }

        const aa = a < 0 ? -a : a;
        const bb = b < 0 ? -b : b;
        if (aa > long.max / bb)
            return false;

        result = a * b;
        return true;
    }
}

@safe pure nothrow @nogc
long divFloor(long q, long r, long d)
{
    if (r == 0)
        return q;
    return r < 0 ? q - 1 : q;
}

@safe pure nothrow @nogc
long divCeiling(long q, long r, long d)
{
    if (r == 0)
        return q;
    return r > 0 ? q + 1 : q;
}

public:
@safe pure nothrow @nogc
ConversionResult!long convertIntegral(
    long value,
    long scaleNumerator,
    long scaleDenominator,
    RoundingMode mode = RoundingMode.towardZero)
{
    auto ratio = reduce(scaleNumerator, scaleDenominator);

    // Cross-cancel value against denominator before multiplication.
    const vg = gcd(magnitude(value), cast(ulong) ratio.denominator);
    const long reducedValue = cast(long)(
        value < 0
            ? -cast(long)(magnitude(value) / vg)
            : cast(long)(magnitude(value) / vg));
    const long reducedDenominator = cast(long)(
        cast(ulong) ratio.denominator / vg);

    // Cross-cancel ratio numerator against denominator too.
    const ng = gcd(magnitude(ratio.numerator), cast(ulong) reducedDenominator);
    const long reducedNumerator = cast(long)(
        ratio.numerator < 0
            ? -cast(long)(magnitude(ratio.numerator) / ng)
            : cast(long)(magnitude(ratio.numerator) / ng));
    const long denominator = cast(long)(
        cast(ulong) reducedDenominator / ng);

    long product;
    if (!multiplyChecked(reducedValue, reducedNumerator, product))
        return ConversionResult!long(0, ConversionStatus.overflow);

    const long q = product / denominator;
    const long r = product % denominator;

    if (r == 0)
        return ConversionResult!long(q, ConversionStatus.exact);

    long rounded;
    final switch (mode)
    {
        case RoundingMode.towardZero:
            rounded = q;
            break;
        case RoundingMode.floor:
            rounded = divFloor(q, r, denominator);
            break;
        case RoundingMode.ceiling:
            rounded = divCeiling(q, r, denominator);
            break;
        case RoundingMode.nearestTiesAway:
            const ulong twice = magnitude(r) * 2UL;
            const ulong d = cast(ulong) denominator;
            if (twice < d)
                rounded = q;
            else
                rounded = product < 0 ? q - 1 : q + 1;
            break;
    }

    return ConversionResult!long(rounded, ConversionStatus.inexact);
}

@safe unittest
{
    enum exact = convertIntegral(1, 1000, 1);
    static assert(exact.status == ConversionStatus.exact);
    static assert(exact.value == 1000);

    enum halfPos = convertIntegral(1, 1, 2, RoundingMode.nearestTiesAway);
    static assert(halfPos.status == ConversionStatus.inexact);
    static assert(halfPos.value == 1);

    enum halfNeg = convertIntegral(-1, 1, 2, RoundingMode.nearestTiesAway);
    static assert(halfNeg.status == ConversionStatus.inexact);
    static assert(halfNeg.value == -1);

    enum floorNeg = convertIntegral(-3, 1, 2, RoundingMode.floor);
    static assert(floorNeg.value == -2);

    enum ceilNeg = convertIntegral(-3, 1, 2, RoundingMode.ceiling);
    static assert(ceilNeg.value == -1);

    enum minIdentity = convertIntegral(long.min, 1, 1);
    static assert(minIdentity.status == ConversionStatus.exact);
    static assert(minIdentity.value == long.min);

    enum overflow = convertIntegral(long.max, 2, 1);
    static assert(overflow.status == ConversionStatus.overflow);

    enum minNegIdentity = convertIntegral(long.min, -1, -1);
    static assert(minNegIdentity.status == ConversionStatus.exact);
    static assert(minNegIdentity.value == long.min);

    enum minHalf = convertIntegral(long.min, 1, 2);
    static assert(minHalf.status == ConversionStatus.exact);
    static assert(minHalf.value == long.min / 2);

    enum cancelled = convertIntegral(long.max - 1, 2, 2);
    static assert(cancelled.status == ConversionStatus.exact);
    static assert(cancelled.value == long.max - 1);

    enum negativeScale = convertIntegral(3, -1, 2, RoundingMode.towardZero);
    static assert(negativeScale.status == ConversionStatus.inexact);
    static assert(negativeScale.value == -1);

    enum negativeScaleFloor = convertIntegral(3, -1, 2, RoundingMode.floor);
    static assert(negativeScaleFloor.value == -2);

    enum negativeScaleCeiling = convertIntegral(3, -1, 2, RoundingMode.ceiling);
    static assert(negativeScaleCeiling.value == -1);

    enum negativeScaleTie = convertIntegral(3, -1, 2, RoundingMode.nearestTiesAway);
    static assert(negativeScaleTie.value == -2);
}


@safe pure nothrow @nogc
ConversionResult!long convertIntegralComposed(
    long value,
    long fromNumerator,
    long fromDenominator,
    long toNumerator,
    long toDenominator,
    RoundingMode mode = RoundingMode.towardZero)
{
    auto fromRatio = reduce(fromNumerator, fromDenominator);
    auto toRatio = reduce(toNumerator, toDenominator);

    // value * (fromN / fromD) / (toN / toD)
    //       = value * fromN * toD / (fromD * toN)
    //
    // Cross-cancel across the two ratios before composition so that otherwise
    // equivalent large exact scales do not overflow merely while forming the
    // intermediate ratio.
    ulong a = magnitude(fromRatio.numerator);
    ulong b = cast(ulong) fromRatio.denominator;
    ulong c = magnitude(toRatio.numerator);
    ulong d = cast(ulong) toRatio.denominator;

    const g1 = gcd(a, c);
    a /= g1;
    c /= g1;

    const g2 = gcd(d, b);
    d /= g2;
    b /= g2;

    const bool negative =
        (fromRatio.numerator < 0) != (toRatio.numerator < 0);

    if (a > cast(ulong) long.max || d > cast(ulong) long.max
        || b > cast(ulong) long.max || c > cast(ulong) long.max)
        return ConversionResult!long(0, ConversionStatus.overflow);

    long composedNumerator;
    if (!multiplyChecked(cast(long) a, cast(long) d, composedNumerator))
        return ConversionResult!long(0, ConversionStatus.overflow);

    long composedDenominator;
    if (!multiplyChecked(cast(long) b, cast(long) c, composedDenominator))
        return ConversionResult!long(0, ConversionStatus.overflow);

    if (negative)
    {
        if (composedNumerator == long.min)
            return convertIntegral(
                value,
                long.min,
                composedDenominator,
                mode);

        composedNumerator = -composedNumerator;
    }

    return convertIntegral(
        value,
        composedNumerator,
        composedDenominator,
        mode);
}

@safe unittest
{
    // The naïve products overflow even though the composed ratio is exactly 1.
    enum large = long.max;
    enum composedIdentity = convertIntegralComposed(
        42,
        large, large - 1,
        large, large - 1);
    static assert(composedIdentity.status == ConversionStatus.exact);
    static assert(composedIdentity.value == 42);

    enum kmToM = convertIntegralComposed(2, 1000, 1, 1, 1);
    static assert(kmToM.status == ConversionStatus.exact);
    static assert(kmToM.value == 2000);

    enum mToKm = convertIntegralComposed(
        1500, 1, 1, 1000, 1, RoundingMode.nearestTiesAway);
    static assert(mToKm.status == ConversionStatus.inexact);
    static assert(mToKm.value == 2);
}
