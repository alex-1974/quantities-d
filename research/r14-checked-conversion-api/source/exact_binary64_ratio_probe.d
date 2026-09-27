module exact_binary64_ratio_probe;

import core.int128 : Cent, mul, udivmod;
import std.math : frexp, ldexp;

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
    bool inexact;
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
Binary64Exact decompose(double value)
{
    assert(value == value);
    assert(value <= double.max && value >= -double.max);

    if (value == 0.0)
        return Binary64Exact(false, 0, 0);

    const bool negative = value < 0.0;
    double x = negative ? -value : value;

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
ulong roundCentQuotientNearestEven(
    Cent numerator,
    ulong denominator,
    out bool inexact)
{
    assert(denominator != 0);

    Cent remainder;
    const quotient = udivmod(numerator, fromUlong128(denominator), remainder);

    assert(quotient.hi == 0);
    ulong q = quotient.lo;

    inexact = !centIsZero(remainder);
    if (!inexact)
        return q;

    const doubledRemainder = mul(remainder, fromUlong128(2));
    const denominator128 = fromUlong128(denominator);

    const bool roundUp =
        centGreater(doubledRemainder, denominator128)
        || (centEqual(doubledRemainder, denominator128)
            && (q & 1UL) != 0);

    if (roundUp)
        ++q;

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
        return RoundedRational(0, 0, false, false);

    ulong s = source.significand;
    ulong n = numerator;
    ulong d = denominator;
    int exponent2 = source.exponent2;

    // Cross-cancel exactly before widening the remaining product.
    auto g = gcd(s, d);
    s /= g;
    d /= g;

    g = gcd(n, d);
    n /= g;
    d /= g;

    // Keep powers of two in the binary exponent. The remaining denominator
    // is odd, which makes the final binary rounding decision explicit.
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

    // s is at most 53 bits and n at most 64 bits, so their exact product
    // fits comfortably in the 128-bit Cent payload.
    Cent exactNumerator = mul(fromUlong128(s), fromUlong128(n));

    // Reduce precision only when the integer part needs more than 53 bits.
    // Shifting is represented by multiplying the denominator by a power of
    // two. For this research kernel, denominator growth is bounded to 64 bits;
    // wider cases will be handled explicitly if the adversarial matrix finds
    // a real consumer-relevant need.
    Cent initialRemainder;
    const initialQuotient = udivmod(exactNumerator, fromUlong128(d), initialRemainder);

    int quotientBits;
    ulong qHi = initialQuotient.hi;
    ulong qLo = initialQuotient.lo;
    if (qHi != 0)
    {
        quotientBits = 64;
        while (qHi != 0)
        {
            ++quotientBits;
            qHi >>= 1;
        }
    }
    else
    {
        quotientBits = bitLength(qLo);
    }

    const int shift = quotientBits > 53 ? quotientBits - 53 : 0;
    ulong scaledDenominator = d;

    if (shift > 0)
    {
        if (shift >= 64 || scaledDenominator > (ulong.max >> shift))
            return RoundedRational(0, 0, true, true);

        scaledDenominator <<= shift;
        exponent2 += shift;
    }

    bool inexact;
    ulong rounded = roundCentQuotientNearestEven(
        exactNumerator,
        scaledDenominator,
        inexact);

    if (bitLength(rounded) > 53)
    {
        rounded >>= 1;
        ++exponent2;
    }

    return RoundedRational(
        rounded,
        exponent2,
        inexact,
        false);
}

@safe pure nothrow @nogc
RoundedRational quantizeBinary64(RoundedRational value)
{
    if (value.overflow || value.significand == 0)
        return value;

    int bits = bitLength(value.significand);
    int topExponent = value.exponent2 + bits - 1;

    // Overflow above the largest finite normal exponent.
    if (topExponent > 1023)
        return RoundedRational(0, 0, true, true);

    // Normal range: reduce significand to at most 53 bits with one
    // round-to-nearest, ties-to-even decision.
    if (topExponent >= -1022)
    {
        if (bits > 53)
        {
            const shift = bits - 53;
            if (shift >= 64)
                return RoundedRational(0, 0, true, true);

            const mask = (1UL << shift) - 1UL;
            const remainder = value.significand & mask;
            ulong upper = value.significand >> shift;
            const halfway = 1UL << (shift - 1);

            const bool roundUp =
                remainder > halfway
                || (remainder == halfway
                    && (upper & 1UL) != 0);

            if (roundUp)
                ++upper;

            value.significand = upper;
            value.exponent2 += shift;
            value.inexact = value.inexact || remainder != 0;

            if (bitLength(value.significand) > 53)
            {
                value.significand >>= 1;
                ++value.exponent2;
            }
        }

        return value;
    }

    // Subnormal range: binary64 values are integer multiples of 2^-1074.
    const shiftToQuantum = -1074 - value.exponent2;

    if (shiftToQuantum <= 0)
        return value;

    if (shiftToQuantum >= 64)
    {
        // Everything is below one half quantum for this bounded probe.
        value.inexact = value.inexact || value.significand != 0;
        value.significand = 0;
        value.exponent2 = -1074;
        return value;
    }

    const mask = (1UL << shiftToQuantum) - 1UL;
    const remainder = value.significand & mask;
    ulong quanta = value.significand >> shiftToQuantum;
    const halfway = 1UL << (shiftToQuantum - 1);

    const bool roundUp =
        remainder > halfway
        || (remainder == halfway
            && (quanta & 1UL) != 0);

    if (roundUp)
        ++quanta;

    value.significand = quanta;
    value.exponent2 = -1074;
    value.inexact = value.inexact || remainder != 0;
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

    const result =
        ldexp(cast(double) value.significand, value.exponent2);
    return negative ? -result : result;
}

@safe unittest
{
    enum minSubnormalValue =
        double.min_normal * double.epsilon;

    // Subnormal tie cases are decided entirely in integer/rational space.
    enum minSub = decompose(minSubnormalValue);

    enum threeHalves = scaleExact(minSub, 3, 2);
    static assert(rebuild(false, threeHalves)
        == minSubnormalValue * 2.0);

    enum fiveHalves = scaleExact(minSub, 5, 2);
    static assert(rebuild(false, fiveHalves)
        == minSubnormalValue * 2.0);

    enum sevenHalves = scaleExact(minSub, 7, 2);
    static assert(rebuild(false, sevenHalves)
        == minSubnormalValue * 4.0);

    // Ordinary exact rational conversion.
    enum oneAndHalf = decompose(1.5);
    enum one = scaleExact(oneAndHalf, 2, 3);
    static assert(rebuild(false, one) == 1.0);
    static assert(!one.inexact);

    // The exact mathematical result is finite; no intermediate double
    // multiplication is permitted to invent overflow.
    enum maximum = decompose(double.max);
    enum twoThirdsMax = scaleExact(maximum, 2, 3);
    static assert(!twoThirdsMax.overflow);
    static assert(rebuild(false, twoThirdsMax) <= double.max);
    static assert(rebuild(false, twoThirdsMax) > 0.0);

    // Exact powers of two remain exact.
    enum powerUp = scaleExact(oneAndHalf, 1024, 1);
    static assert(rebuild(false, powerUp) == 1536.0);
    static assert(!powerUp.inexact);

    // Runtime parity for the previously divergent LDC tie.
    const runtimeMinSub = decompose(
        double.min_normal * double.epsilon);
    const runtimeThreeHalves =
        scaleExact(runtimeMinSub, 3, 2);
    assert(rebuild(false, runtimeThreeHalves)
        == minSubnormalValue * 2.0);

    const runtimeMaximum = decompose(double.max);
    const runtimeTwoThirds =
        scaleExact(runtimeMaximum, 2, 3);
    assert(!runtimeTwoThirds.overflow);
    assert(rebuild(false, runtimeTwoThirds) <= double.max);

    // True overflow must be distinguished from avoidable intermediate overflow.
    enum trueOverflow = scaleExact(maximum, 2, 1);
    static assert(
        quantizeBinary64(trueOverflow).overflow
        || rebuild(false, trueOverflow) > double.max);

    // True underflow below half the minimum subnormal rounds to zero.
    enum halfMin = scaleExact(minSub, 1, 2);
    static assert(rebuild(false, halfMin) == 0.0);

    // Large rational components should not invent overflow when the exact
    // ratio is close to one.
    enum oneValue = decompose(1.0);
    enum largeBalanced = scaleExact(
        oneValue,
        cast(ulong) long.max,
        cast(ulong)(long.max - 2));
    static assert(!largeBalanced.overflow);
    static assert(rebuild(false, largeBalanced) == 1.0);

    // Exact large power-of-two scale remains representable where expected.
    enum scaleUp = scaleExact(oneAndHalf, 1UL << 20, 1);
    static assert(!scaleUp.overflow);
    static assert(rebuild(false, scaleUp)
        == 1.5 * cast(double)(1UL << 20));

    // Negative values share the same magnitude kernel.
    enum negativeThreeHalves = scaleExact(decompose(-1.5), 2, 3);
    static assert(rebuild(true, negativeThreeHalves) == -1.0);

    // Signed zero must be preserved by final reconstruction.
    enum zeroScaled = scaleExact(decompose(-0.0), 3, 2);
    static assert(rebuild(true, zeroScaled) == 0.0);
    static assert(1.0 / rebuild(true, zeroScaled) == -double.infinity);

    // Largest subnormal -> exact transition into the minimum normal value.
    enum largestSubnormal =
        decompose(double.min_normal - minSubnormalValue);
    enum nextQuantum = scaleExact(largestSubnormal, 1, 1);
    static assert(rebuild(false, nextQuantum)
        == double.min_normal - minSubnormalValue);

    // Scaling the largest subnormal upward by one minimum-subnormal quantum
    // equivalent crosses exactly onto the normal boundary.
    enum normalBoundarySource =
        decompose(double.min_normal / 2.0);
    enum normalBoundary = scaleExact(normalBoundarySource, 2, 1);
    static assert(rebuild(false, normalBoundary) == double.min_normal);

    // A ratio with a very large odd denominator exercises denominator growth
    // near the current research-kernel limit without changing the value much.
    enum largeOddDenominator = cast(ulong) long.max;
    enum denominatorStress = scaleExact(
        decompose(1.0),
        largeOddDenominator - 2,
        largeOddDenominator);
    static assert(!denominatorStress.overflow);
    static assert(rebuild(false, denominatorStress) == 1.0);
}
