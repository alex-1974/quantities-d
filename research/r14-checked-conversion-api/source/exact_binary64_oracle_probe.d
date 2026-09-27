module exact_binary64_oracle_probe;

import core.int128 : Cent, mul, udivmod;
import std.math : frexp, ldexp;

struct Parts
{
    ulong significand;
    int exponent2;
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
int bitLength(Cent value)
{
    return value.hi != 0 ? 64 + bitLength(value.hi) : bitLength(value.lo);
}

@safe pure nothrow @nogc
Cent fromUlong(ulong value)
{
    return Cent(value, 0);
}

@safe pure nothrow @nogc
bool greater(Cent a, Cent b)
{
    return a.hi > b.hi || (a.hi == b.hi && a.lo > b.lo);
}

@safe pure nothrow @nogc
bool equal(Cent a, Cent b)
{
    return a.hi == b.hi && a.lo == b.lo;
}

@safe pure nothrow @nogc
Cent shl(Cent value, int shift)
{
    foreach (_; 0 .. shift)
    {
        assert((value.hi & (1UL << 63)) == 0);
        value.hi = (value.hi << 1) | (value.lo >> 63);
        value.lo <<= 1;
    }
    return value;
}

@safe pure nothrow @nogc
Parts decompose(double value)
{
    if (value == 0.0)
        return Parts(0, 0);

    const x = value < 0.0 ? -value : value;
    int exponent;
    const fraction = frexp(x, exponent);
    ulong significand = cast(ulong) ldexp(fraction, 53);
    int exponent2 = exponent - 53;

    while ((significand & 1UL) == 0)
    {
        significand >>= 1;
        ++exponent2;
    }

    return Parts(significand, exponent2);
}

@safe pure nothrow @nogc
Parts roundPositiveRational(Cent numerator, ulong denominator, int exponent2)
{
    assert(denominator != 0);

    // Determine k = floor(log2(numerator / denominator)).
    int k = bitLength(numerator) - bitLength(denominator) - 1;

    if (k >= 0)
    {
        const atK = shl(fromUlong(denominator), k);
        const atKPlusOne = shl(fromUlong(denominator), k + 1);

        if (greater(atK, numerator))
            --k;
        else if (!greater(atKPlusOne, numerator))
            ++k;
    }
    else
    {
        const negK = -k;
        const atK = shl(numerator, negK);
        const atKPlusOne = shl(numerator, negK - 1);

        if (greater(fromUlong(denominator), atK))
            --k;
        else if (!greater(fromUlong(denominator), atKPlusOne))
            ++k;
    }

    // Normal candidate: M = round((numerator/denominator) * 2^(52-k)).
    // E = exponent2 + k - 52.
    const int shift = 52 - k;
    Cent scaledNumerator = numerator;
    Cent scaledDenominator = fromUlong(denominator);

    if (shift >= 0)
        scaledNumerator = shl(scaledNumerator, shift);
    else
        scaledDenominator = shl(scaledDenominator, -shift);

    Cent remainder;
    const q128 = udivmod(scaledNumerator, scaledDenominator, remainder);
    assert(q128.hi == 0);
    ulong q = q128.lo;

    if (remainder.hi != 0 || remainder.lo != 0)
    {
        const twiceR = mul(remainder, fromUlong(2));
        if (greater(twiceR, scaledDenominator)
            || (equal(twiceR, scaledDenominator) && (q & 1UL) != 0))
        {
            ++q;
        }
    }

    int outExponent = exponent2 + k - 52;
    if (bitLength(q) == 54)
    {
        q >>= 1;
        ++outExponent;
    }

    return Parts(q, outExponent);
}

@safe pure nothrow @nogc
Cent subtractNonNegative(Cent a, Cent b)
{
    assert(greater(a, b) || equal(a, b));

    const ulong lo = a.lo - b.lo;
    const ulong borrow = a.lo < b.lo ? 1UL : 0UL;
    const ulong hi = a.hi - b.hi - borrow;

    return Cent(lo, hi);
}

@safe pure nothrow @nogc
bool candidateCloserToRational(
    ulong candidateA,
    ulong candidateB,
    int exponent2,
    ulong numerator,
    ulong denominator)
{
    // Compare |candidate * 2^exponent2 - numerator/denominator|
    // exactly for the negative-exponent cases used by this oracle probe.
    assert(exponent2 < 0);

    const shift = -exponent2;

    // Compare the numerators over the common positive denominator
    // denominator * 2^shift:
    //
    //   candidate * 2^-shift - numerator/denominator
    // = (candidate*denominator - numerator*2^shift)
    //   / (denominator*2^shift)
    //
    // Only the absolute integer numerators are needed for ordering.
    const candidateAScaled =
        mul(fromUlong(candidateA), fromUlong(denominator));
    const candidateBScaled =
        mul(fromUlong(candidateB), fromUlong(denominator));

    Cent targetScaled = fromUlong(numerator);
    targetScaled = shl(targetScaled, shift);

    const Cent aDiff = greater(candidateAScaled, targetScaled)
        ? subtractNonNegative(candidateAScaled, targetScaled)
        : subtractNonNegative(targetScaled, candidateAScaled);
    const Cent bDiff = greater(candidateBScaled, targetScaled)
        ? subtractNonNegative(candidateBScaled, targetScaled)
        : subtractNonNegative(targetScaled, candidateBScaled);

    return greater(bDiff, aDiff);
}

@safe unittest
{
    // 1/10 should match the actual binary64 literal exactly.
    enum literalTenth = decompose(0.1);
    static assert(literalTenth.significand == 7205759403792793UL);
    static assert(literalTenth.exponent2 == -56);

    // Direct nearest-neighbour oracle around 0.1.
    static assert(candidateCloserToRational(
        7205759403792793UL,
        7205759403792794UL,
        -56,
        1,
        10));

    enum oneTenth = roundPositiveRational(fromUlong(1), 10, 0);
    static assert(oneTenth.significand == literalTenth.significand);
    static assert(oneTenth.exponent2 == literalTenth.exponent2);

    // 1/2 and 3/2 exact sanity.
    enum half = roundPositiveRational(fromUlong(1), 2, 0);
    enum literalHalf = decompose(0.5);
    static assert(half.significand == literalHalf.significand);
    static assert(half.exponent2 == literalHalf.exponent2);

    enum threeHalves = roundPositiveRational(fromUlong(3), 2, 0);
    enum literalThreeHalves = decompose(1.5);
    static assert(threeHalves.significand == literalThreeHalves.significand);
    static assert(threeHalves.exponent2 == literalThreeHalves.exponent2);
}
