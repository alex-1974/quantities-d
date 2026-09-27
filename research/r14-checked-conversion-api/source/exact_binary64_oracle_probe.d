module exact_binary64_oracle_probe;

import core.int128 : Cent, mul, udivmod;

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

@trusted pure nothrow @nogc
ulong rawBits(double value)
{
    union Bits
    {
        double d;
        ulong u;
    }

    Bits bits;
    bits.d = value;
    return bits.u;
}

@trusted pure nothrow @nogc
Parts decompose(double value)
{
    const ulong raw = rawBits(value);
    const ulong exponentBits = (raw >> 52) & 0x7FFUL;
    const ulong fractionBits = raw & 0x000F_FFFF_FFFF_FFFFUL;

    if (exponentBits == 0 && fractionBits == 0)
        return Parts(0, 0);

    ulong significand;
    int exponent2;

    if (exponentBits == 0)
    {
        // Subnormal: value = fractionBits * 2^-1074.
        significand = fractionBits;
        exponent2 = -1074;
    }
    else
    {
        // Normal: value = (2^52 + fractionBits) * 2^(biasedExponent-1023-52).
        significand = (1UL << 52) | fractionBits;
        exponent2 = cast(int) exponentBits - 1023 - 52;
    }

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

@safe pure nothrow @nogc
Cent rationalDistanceNumerator(
    ulong candidate,
    int exponent2,
    ulong numerator,
    ulong denominator)
{
    assert(exponent2 < 0);

    const shift = -exponent2;
    const candidateScaled =
        mul(fromUlong(candidate), fromUlong(denominator));

    Cent targetScaled = fromUlong(numerator);
    targetScaled = shl(targetScaled, shift);

    return greater(candidateScaled, targetScaled)
        ? subtractNonNegative(candidateScaled, targetScaled)
        : subtractNonNegative(targetScaled, candidateScaled);
}

@safe unittest
{
    // decompose() strips powers of two from the significand. Therefore
    // binary64 0.1 appears canonically as:
    //
    //     3602879701896397 * 2^-55
    //
    // which is exactly the same value as
    //
    //     7205759403792794 * 2^-56.
    enum literalTenth = decompose(0.1);
    static assert(literalTenth.significand == 3602879701896397UL);
    static assert(literalTenth.exponent2 == -55);

    // Compare the actual binary64 neighbours on a shared 2^-56 lattice.
    enum lowerDistance = rationalDistanceNumerator(
        7205759403792793UL, -56, 1, 10);
    enum roundedDistance = rationalDistanceNumerator(
        7205759403792794UL, -56, 1, 10);
    enum upperDistance = rationalDistanceNumerator(
        7205759403792795UL, -56, 1, 10);

    static assert(lowerDistance.hi == 0 && lowerDistance.lo == 6UL);
    static assert(roundedDistance.hi == 0 && roundedDistance.lo == 4UL);
    static assert(upperDistance.hi == 0 && upperDistance.lo == 14UL);

    static assert(greater(lowerDistance, roundedDistance));
    static assert(greater(upperDistance, roundedDistance));

    // The standalone rational-rounding oracle must agree with decompose(0.1)
    // after canonical power-of-two reduction.
    enum oneTenth = roundPositiveRational(fromUlong(1), 10, 0);
    static assert(oneTenth.significand == literalTenth.significand);
    static assert(oneTenth.exponent2 == literalTenth.exponent2);

    // Exact sanity cases.
    enum half = roundPositiveRational(fromUlong(1), 2, 0);
    enum literalHalf = decompose(0.5);
    static assert(half.significand == literalHalf.significand);
    static assert(half.exponent2 == literalHalf.exponent2);

    enum threeHalves = roundPositiveRational(fromUlong(3), 2, 0);
    enum literalThreeHalves = decompose(1.5);
    static assert(threeHalves.significand == literalThreeHalves.significand);
    static assert(threeHalves.exponent2 == literalThreeHalves.exponent2);
}
