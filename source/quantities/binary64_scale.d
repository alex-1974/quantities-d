module quantities.binary64_scale;

import core.int128 : Cent, mul, udivmod;
import std.math : frexp, ldexp;

struct Binary64ScaleResult
{
    double value;
    bool overflow;
}

private:
struct Binary64Exact
{
    bool negative;
    ulong significand;
    int exponent2;
}

struct RoundedRational
{
    ulong significand;
    int exponent2;
    bool overflow;
}

struct RoundProbe
{
    ulong quotient;
    ulong remainderLo;
    ulong remainderHi;
    ulong denominator;
    int exponent2;
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

@safe pure nothrow @nogc
Binary64Exact decompose(double value)
{
    if (value == 0.0)
        return Binary64Exact(value < 0.0, 0, 0);

    const bool negative = value < 0.0;
    const x = negative ? -value : value;

    int exponent;
    const fraction = frexp(x, exponent);

    ulong significand = cast(ulong) ldexp(fraction, 53);
    int exponent2 = exponent - 53;

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

@safe pure nothrow @nogc
Cent fromUlong128(ulong value)
{
    return Cent(value, 0);
}

@safe pure nothrow @nogc
bool centIsZero(Cent value)
{
    return value.lo == 0 && value.hi == 0;
}

@safe pure nothrow @nogc
bool centGreater(Cent a, Cent b)
{
    return a.hi > b.hi || (a.hi == b.hi && a.lo > b.lo);
}

@safe pure nothrow @nogc
bool centEqual(Cent a, Cent b)
{
    return a.hi == b.hi && a.lo == b.lo;
}

@safe pure nothrow @nogc
RoundProbe probeNormalizedDivision(
    double value,
    ulong numerator,
    ulong denominator)
{
    auto source = decompose(value);

    ulong s = source.significand;
    ulong n = numerator;
    ulong d = denominator;
    int exponent2 = source.exponent2;

    auto g = gcd(s, d);
    s /= g;
    d /= g;

    g = gcd(n, d);
    n /= g;
    d /= g;

    while ((n & 1UL) == 0)
    {
        n >>= 1;
        ++exponent2;
    }

    while ((d & 1UL) == 0)
    {
        d >>= 1;
        --exponent2;
    }

    Cent scaledNumerator =
        mul(fromUlong128(s), fromUlong128(n));

    Cent remainder;
    auto quotient =
        udivmod(scaledNumerator, fromUlong128(d), remainder);

    int quotientBits = quotient.hi != 0
        ? 64 + bitLength(quotient.hi)
        : bitLength(quotient.lo);

    while (quotientBits < 53)
    {
        scaledNumerator.hi =
            (scaledNumerator.hi << 1) | (scaledNumerator.lo >> 63);
        scaledNumerator.lo <<= 1;
        --exponent2;

        quotient =
            udivmod(scaledNumerator, fromUlong128(d), remainder);
        quotientBits = quotient.hi != 0
            ? 64 + bitLength(quotient.hi)
            : bitLength(quotient.lo);
    }

    return RoundProbe(
        quotient.lo,
        remainder.lo,
        remainder.hi,
        d,
        exponent2);
}

@safe pure nothrow @nogc
ulong roundCentQuotientNearestEven(
    Cent numerator,
    ulong denominator)
{
    Cent remainder;
    const quotient =
        udivmod(numerator, fromUlong128(denominator), remainder);

    assert(quotient.hi == 0);
    ulong q = quotient.lo;

    if (centIsZero(remainder))
        return q;

    const doubledRemainder = mul(remainder, fromUlong128(2));
    const denominator128 = fromUlong128(denominator);

    if (centGreater(doubledRemainder, denominator128)
        || (centEqual(doubledRemainder, denominator128)
            && (q & 1UL) != 0))
    {
        ++q;
    }

    return q;
}

@safe pure nothrow @nogc
RoundedRational scaleExact(
    Binary64Exact source,
    ulong numerator,
    ulong denominator)
{
    assert(denominator != 0);

    if (source.significand == 0 || numerator == 0)
        return RoundedRational(0, 0, false);

    ulong s = source.significand;
    ulong n = numerator;
    ulong d = denominator;
    int exponent2 = source.exponent2;

    auto g = gcd(s, d);
    s /= g;
    d /= g;

    g = gcd(n, d);
    n /= g;
    d /= g;

    while ((n & 1UL) == 0)
    {
        n >>= 1;
        ++exponent2;
    }

    while ((d & 1UL) == 0)
    {
        d >>= 1;
        --exponent2;
    }

    const exactNumerator =
        mul(fromUlong128(s), fromUlong128(n));

    // Normalize the exact rational so that integer division yields roughly
    // 53 significant bits. This also handles values smaller than 1, where the
    // unscaled integer quotient would otherwise be zero.
    Cent scaledNumerator = exactNumerator;
    ulong scaledDenominator = d;

    Cent remainder;
    auto quotient =
        udivmod(scaledNumerator, fromUlong128(scaledDenominator), remainder);

    int quotientBits;
    if (quotient.hi != 0)
    {
        quotientBits = 64;
        ulong scan = quotient.hi;
        while (scan != 0)
        {
            ++quotientBits;
            scan >>= 1;
        }
    }
    else
    {
        quotientBits = bitLength(quotient.lo);
    }

    // For ratios below 1, generate binary fraction bits by shifting the exact
    // numerator left. Cent gives enough headroom for the 53-bit source
    // significand times a 64-bit scale plus this normalization.
    while (quotientBits < 53)
    {
        if ((scaledNumerator.hi & (1UL << 63)) != 0)
            break;

        scaledNumerator.hi =
            (scaledNumerator.hi << 1) | (scaledNumerator.lo >> 63);
        scaledNumerator.lo <<= 1;
        --exponent2;

        quotient =
            udivmod(scaledNumerator, fromUlong128(scaledDenominator), remainder);

        if (quotient.hi != 0)
        {
            quotientBits = 64;
            ulong scan = quotient.hi;
            while (scan != 0)
            {
                ++quotientBits;
                scan >>= 1;
            }
        }
        else
        {
            quotientBits = bitLength(quotient.lo);
        }
    }

    // If the quotient has more than 53 bits, reduce by shifting the
    // denominator instead. This preserves the exact rational and defers the
    // only rounding decision to roundCentQuotientNearestEven.
    if (quotientBits > 53)
    {
        const shift = quotientBits - 53;
        if (shift >= 64 || scaledDenominator > (ulong.max >> shift))
            return RoundedRational(0, 0, true);

        scaledDenominator <<= shift;
        exponent2 += shift;
    }

    ulong rounded = roundCentQuotientNearestEven(
        scaledNumerator, scaledDenominator);

    if (bitLength(rounded) > 53)
    {
        rounded >>= 1;
        ++exponent2;
    }

    return RoundedRational(rounded, exponent2, false);
}

@safe pure nothrow @nogc
RoundedRational quantizeBinary64(RoundedRational value)
{
    if (value.overflow || value.significand == 0)
        return value;

    int bits = bitLength(value.significand);
    int topExponent = value.exponent2 + bits - 1;

    if (topExponent > 1023)
        return RoundedRational(0, 0, true);

    if (topExponent >= -1022)
        return value;

    const shiftToQuantum = -1074 - value.exponent2;

    if (shiftToQuantum <= 0)
        return value;

    if (shiftToQuantum >= 64)
    {
        value.significand = 0;
        value.exponent2 = -1074;
        return value;
    }

    const mask = (1UL << shiftToQuantum) - 1UL;
    const remainder = value.significand & mask;
    ulong quanta = value.significand >> shiftToQuantum;
    const halfway = 1UL << (shiftToQuantum - 1);

    if (remainder > halfway
        || (remainder == halfway && (quanta & 1UL) != 0))
    {
        ++quanta;
    }

    value.significand = quanta;
    value.exponent2 = -1074;
    return value;
}

@safe pure nothrow @nogc
double rebuild(bool negative, RoundedRational value)
{
    value = quantizeBinary64(value);

    if (value.overflow)
        return negative ? -double.infinity : double.infinity;

    if (value.significand == 0)
        return negative ? -0.0 : 0.0;

    // value.significand is already rounded to at most 53 bits. Converting that
    // integer to double is therefore exact, and ldexp only applies a power of
    // two. No additional decimal/rational rounding decision is permitted here.
    const double exactSignificand = cast(double) value.significand;
    const double result = ldexp(exactSignificand, value.exponent2);

    return negative ? -result : result;
}

public:
@safe pure nothrow @nogc
Binary64ScaleResult scaleBinary64(
    double value,
    long numerator,
    long denominator)
{
    assert(denominator > 0);

    if (value == 0.0 || numerator == 0)
        return Binary64ScaleResult(
            (value < 0.0) != (numerator < 0) ? -0.0 : 0.0,
            false);

    const source = decompose(value);

    const numeratorMagnitude = numerator < 0
        ? cast(ulong)(-(numerator + 1)) + 1UL
        : cast(ulong) numerator;

    auto scaled = scaleExact(
        source, numeratorMagnitude, cast(ulong) denominator);

    scaled = quantizeBinary64(scaled);
    if (scaled.overflow)
        return Binary64ScaleResult(0.0, true);

    const negative = source.negative != (numerator < 0);
    return Binary64ScaleResult(rebuild(negative, scaled), false);
}

@safe unittest
{
    enum minSubnormal = double.min_normal * double.epsilon;

    enum maxTwoThirds = scaleBinary64(double.max, 2, 3);
    static assert(!maxTwoThirds.overflow);
    static assert(maxTwoThirds.value > 0.0);
    static assert(maxTwoThirds.value <= double.max);

    enum subnormalTie = scaleBinary64(minSubnormal, 3, 2);
    static assert(!subnormalTie.overflow);
    static assert(subnormalTie.value == minSubnormal * 2.0);

    enum halfMin = scaleBinary64(minSubnormal, 1, 2);
    static assert(!halfMin.overflow);
    static assert(halfMin.value == 0.0);

    enum trueOverflow = scaleBinary64(double.max, 2, 1);
    static assert(trueOverflow.overflow);

    enum negative = scaleBinary64(-1.5, 2, 3);
    static assert(!negative.overflow);
    static assert(negative.value == -1.0);

    enum tenthProbe = probeNormalizedDivision(1.0, 1, 10);
    static assert(tenthProbe.quotient == 7205759403792793UL);
    static assert(tenthProbe.remainderLo == 3UL);
    static assert(tenthProbe.remainderHi == 0UL);
    static assert(tenthProbe.denominator == 5UL);
    static assert(tenthProbe.exponent2 == -56);

    enum tenthRounded = scaleExact(decompose(1.0), 1, 10);
    static assert(tenthRounded.significand == 7205759403792794UL);
    static assert(tenthRounded.exponent2 == -56);

    enum tenth = scaleBinary64(1.0, 1, 10);
    static assert(!tenth.overflow);
    enum tenthParts = decompose(tenth.value);
    enum literalTenthParts = decompose(0.1);
    static assert(tenthParts.significand == literalTenthParts.significand);
    static assert(tenthParts.exponent2 == literalTenthParts.exponent2);
}
