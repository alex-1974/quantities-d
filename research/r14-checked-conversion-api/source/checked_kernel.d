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
}
