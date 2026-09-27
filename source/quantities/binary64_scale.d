module quantities.binary64_scale;

import core.int128 : Cent, mul, udivmod;
import core.stdc.string : memcpy;
import std.math : ldexp;

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
ulong binary64Bits(double value)
{
    ulong bits;

    () @trusted {
        memcpy(&bits, &value, double.sizeof);
    }();

    return bits;
}

@safe pure nothrow @nogc
Binary64Exact decompose(double value)
{
    const bits = binary64Bits(value);
    const negative = (bits >> 63) != 0;
    const exponentField = cast(uint)((bits >> 52) & 0x7ffUL);
    const fraction = bits & ((1UL << 52) - 1UL);

    if (exponentField == 0)
    {
        // Zero or subnormal: fraction * 2^-1074.
        return Binary64Exact(negative, fraction, -1074);
    }

    // scaleBinary64 is called only for finite values.
    assert(exponentField != 0x7ff);

    // Normal:
    //   (2^52 + fraction) * 2^(biasedExponent - 1023 - 52)
    return Binary64Exact(
        negative,
        (1UL << 52) | fraction,
        cast(int) exponentField - 1023 - 52);
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
int centBitLength(Cent value)
{
    if (value.hi != 0)
        return 64 + bitLength(value.hi);
    return bitLength(value.lo);
}

@safe pure nothrow @nogc
Cent shlCent(Cent value, int shift, out bool overflow)
{
    overflow = false;

    foreach (_; 0 .. shift)
    {
        if ((value.hi & (1UL << 63)) != 0)
        {
            overflow = true;
            return value;
        }

        value.hi = (value.hi << 1) | (value.lo >> 63);
        value.lo <<= 1;
    }

    return value;
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

    // Determine floor(log2(exactNumerator / d)) exactly.
    // Start from the bit-length difference, then correct by one comparison.
    int ratioExponent = centBitLength(exactNumerator) - bitLength(d);

    if (ratioExponent >= 0)
    {
        bool shiftOverflow;
        const scaledDen =
            shlCent(fromUlong128(d), ratioExponent, shiftOverflow);

        if (shiftOverflow || centGreater(scaledDen, exactNumerator))
            --ratioExponent;
    }
    else
    {
        bool shiftOverflow;
        const scaledNum =
            shlCent(exactNumerator, -ratioExponent, shiftOverflow);

        if (!shiftOverflow
            && centGreater(fromUlong128(d), scaledNum))
            --ratioExponent;
    }

    // Let r = exactNumerator / d. The represented value is r * 2^exponent2.
    // If floor(log2(r)) == ratioExponent, a normalized 53-bit significand is
    //
    //     M = round(r * 2^(52 - ratioExponent))
    //
    // and the corresponding binary exponent is
    //
    //     E = exponent2 + ratioExponent - 52.
    //
    // Note that exponent2 belongs only in E. It must not also influence the
    // scaling used to compute M.
    const int targetExponent = exponent2 + ratioExponent - 52;
    const int significandShift = 52 - ratioExponent;

    Cent scaledNumerator = exactNumerator;
    ulong scaledDenominator = d;

    if (significandShift > 0)
    {
        bool shiftOverflow;
        scaledNumerator = shlCent(
            scaledNumerator, significandShift, shiftOverflow);
        if (shiftOverflow)
            return RoundedRational(0, 0, true);
    }
    else if (significandShift < 0)
    {
        const shift = -significandShift;
        if (shift >= 64 || scaledDenominator > (ulong.max >> shift))
            return RoundedRational(0, 0, true);

        scaledDenominator <<= shift;
    }

    ulong rounded = roundCentQuotientNearestEven(
        scaledNumerator, scaledDenominator);

    int roundedExponent = targetExponent;

    if (bitLength(rounded) > 53)
    {
        rounded >>= 1;
        ++roundedExponent;
    }

    return RoundedRational(rounded, roundedExponent, false);
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

    // R14/ADR 0007: arbitrary double CTFE does not promise reconstruction
    // of the stored binary64 source lattice on the baseline compilers.
    // Keep compile-time coverage for overflow classification here, but do not
    // assert represented-source binary64 equality for 1/10 at CTFE.
    enum tenth = scaleBinary64(1.0, 1, 10);
    static assert(!tenth.overflow);
}
