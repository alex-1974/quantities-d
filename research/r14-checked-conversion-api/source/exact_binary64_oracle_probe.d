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
    int k = bitLength(numerator) - bitLength(denominator);

    if (k >= 0)
    {
        const scaledDen = shl(fromUlong(denominator), k);
        if (greater(scaledDen, numerator))
            --k;
    }
    else
    {
        const scaledNum = shl(numerator, -k);
        if (greater(fromUlong(denominator), scaledNum))
            --k;
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

@safe unittest
{
    // 1/10 should match the actual binary64 literal exactly.
    enum oneTenth = roundPositiveRational(fromUlong(1), 10, 0);
    enum literalTenth = decompose(0.1);
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
