module r04_17_real80_kernel;

import std.math : frexp, ldexp;

static assert(real.mant_dig <= 64,
    "R04.17 real80 probe requires real.mant_dig <= 64.");

struct UInt192
{
    ulong lo;
    ulong mid;
    ulong hi;
}

struct RealExact
{
    ulong significand;
    int exponent2;
    bool negative;
}

struct ExactRatio192
{
    UInt192 numerator;
    UInt192 denominator;
    int exponent2;
    bool negative;
}

private int bitLength(ulong value)
    @safe pure nothrow @nogc
{
    int result;
    while (value != 0)
    {
        ++result;
        value >>= 1;
    }
    return result;
}

private int bitLength(UInt192 value)
    @safe pure nothrow @nogc
{
    if (value.hi != 0)
        return 128 + bitLength(value.hi);
    if (value.mid != 0)
        return 64 + bitLength(value.mid);
    return bitLength(value.lo);
}

private UInt192 fromUlong(ulong value)
    @safe pure nothrow @nogc
{
    return UInt192(value, 0, 0);
}

private int compare(UInt192 a, UInt192 b)
    @safe pure nothrow @nogc
{
    if (a.hi < b.hi) return -1;
    if (a.hi > b.hi) return 1;
    if (a.mid < b.mid) return -1;
    if (a.mid > b.mid) return 1;
    if (a.lo < b.lo) return -1;
    if (a.lo > b.lo) return 1;
    return 0;
}

private UInt192 subtract(UInt192 a, UInt192 b)
    @safe pure nothrow @nogc
{
    assert(compare(a, b) >= 0);

    const borrow0 = a.lo < b.lo ? 1UL : 0UL;
    const lo = a.lo - b.lo;

    const midSub = b.mid + borrow0;
    const carry0 = midSub < b.mid ? 1UL : 0UL;
    const borrow1 =
        (carry0 != 0 || a.mid < midSub) ? 1UL : 0UL;
    const mid = a.mid - midSub;

    return UInt192(
        lo,
        mid,
        a.hi - b.hi - borrow1);
}

private UInt192 shiftLeft(UInt192 value, int shift)
    @safe pure nothrow @nogc
{
    assert(shift >= 0);

    foreach (_; 0 .. shift)
    {
        assert((value.hi & (1UL << 63)) == 0);
        value.hi = (value.hi << 1) | (value.mid >> 63);
        value.mid = (value.mid << 1) | (value.lo >> 63);
        value.lo <<= 1;
    }

    return value;
}

private UInt192 multiply64(ulong a, ulong b)
    @safe pure nothrow @nogc
{
    enum ulong mask = 0xffff_ffffUL;

    const a0 = a & mask;
    const a1 = a >> 32;
    const b0 = b & mask;
    const b1 = b >> 32;

    const p00 = a0 * b0;
    const p01 = a0 * b1;
    const p10 = a1 * b0;
    const p11 = a1 * b1;

    const middle =
        (p00 >> 32)
        + (p01 & mask)
        + (p10 & mask);

    return UInt192(
        (p00 & mask) | (middle << 32),
        p11
            + (p01 >> 32)
            + (p10 >> 32)
            + (middle >> 32),
        0);
}

private UInt192 multiply128By64(UInt192 a, ulong b)
    @safe pure nothrow @nogc
{
    assert(a.hi == 0);

    const low = multiply64(a.lo, b);
    const high = multiply64(a.mid, b);

    const mid = low.mid + high.lo;
    const carry = mid < low.mid ? 1UL : 0UL;

    return UInt192(
        low.lo,
        mid,
        high.mid + carry);
}

private ulong gcd(ulong a, ulong b)
    @safe pure nothrow @nogc
{
    while (b != 0)
    {
        const r = a % b;
        a = b;
        b = r;
    }
    return a;
}

private void cancel(ref ulong a, ref ulong b)
    @safe pure nothrow @nogc
{
    const g = gcd(a, b);
    if (g > 1)
    {
        a /= g;
        b /= g;
    }
}

RealExact decomposeReal(real value)
    @safe pure nothrow @nogc
{
    assert(value != 0.0L);
    assert(value == value);
    assert(value != real.infinity);
    assert(value != -real.infinity);

    int exponent;
    real fraction = frexp(value, exponent);

    const negative = fraction < 0.0L;
    if (negative)
        fraction = -fraction;

    const scaled =
        ldexp(fraction, real.mant_dig);
    const significand = cast(ulong)scaled;

    assert(cast(real)significand == scaled);

    return RealExact(
        significand,
        exponent - real.mant_dig,
        negative);
}

private struct NormalizedRatio
{
    UInt192 numerator;
    UInt192 denominator;
    int exponent2;
}

private NormalizedRatio normalize(
    UInt192 numerator,
    UInt192 denominator)
    @safe pure nothrow @nogc
{
    int exponent2 =
        bitLength(numerator)
        - bitLength(denominator);

    UInt192 a;
    UInt192 b;

    if (exponent2 >= 0)
    {
        a = numerator;
        b = shiftLeft(denominator, exponent2);
    }
    else
    {
        a = shiftLeft(numerator, -exponent2);
        b = denominator;
    }

    if (compare(a, b) < 0)
    {
        --exponent2;

        if (exponent2 >= 0)
        {
            a = numerator;
            b = shiftLeft(denominator, exponent2);
        }
        else
        {
            a = shiftLeft(numerator, -exponent2);
            b = denominator;
        }
    }

    assert(compare(a, b) >= 0);
    return NormalizedRatio(a, b, exponent2);
}

private struct RoundedSignificand
{
    ulong value;
    bool carry;
}

private RoundedSignificand roundedNormalizedSignificand(
    UInt192 numerator,
    UInt192 denominator,
    int fractionBits)
    @safe pure nothrow @nogc
{
    assert(fractionBits >= 0 && fractionBits <= 63);
    assert(compare(numerator, denominator) >= 0);

    ulong result = 1UL << fractionBits;
    UInt192 remainder =
        subtract(numerator, denominator);

    foreach (i; 0 .. fractionBits)
    {
        remainder = shiftLeft(remainder, 1);

        if (compare(remainder, denominator) >= 0)
        {
            result |= 1UL << (fractionBits - 1 - i);
            remainder = subtract(remainder, denominator);
        }
    }

    const doubled = shiftLeft(remainder, 1);
    const cmp = compare(doubled, denominator);
    const roundUp =
        cmp > 0 || (cmp == 0 && (result & 1UL) != 0);

    if (!roundUp)
        return RoundedSignificand(result, false);

    if (result == ulong.max)
        return RoundedSignificand(1UL << fractionBits, true);

    return RoundedSignificand(result + 1, false);
}

private real signedZero(bool negative)
    @safe pure nothrow @nogc
{
    return negative ? -0.0L : 0.0L;
}

private real quantize(ExactRatio192 exact)
    @safe pure nothrow @nogc
{
    const normalized =
        normalize(exact.numerator, exact.denominator);

    int topExponent =
        exact.exponent2
        + normalized.exponent2;

    enum int maxTopExponent = real.max_exp - 1;
    enum int minNormalTopExponent = real.min_exp - 1;
    enum int minSubnormalExponent =
        real.min_exp - real.mant_dig;
    enum int fractionBits = real.mant_dig - 1;

    if (topExponent > maxTopExponent)
        return exact.negative
            ? -real.infinity
            : real.infinity;

    if (topExponent >= minNormalTopExponent)
    {
        auto rounded =
            roundedNormalizedSignificand(
                normalized.numerator,
                normalized.denominator,
                fractionBits);

        if (rounded.carry)
        {
            ++topExponent;

            if (topExponent > maxTopExponent)
                return exact.negative
                    ? -real.infinity
                    : real.infinity;
        }

        real value =
            ldexp(
                cast(real)rounded.value,
                topExponent - fractionBits);

        return exact.negative ? -value : value;
    }

    const quantumPower =
        topExponent - minSubnormalExponent;

    ulong quanta;

    if (quantumPower < -1)
    {
        quanta = 0;
    }
    else if (quantumPower == -1)
    {
        quanta =
            compare(
                normalized.numerator,
                normalized.denominator) == 0
            ? 0UL
            : 1UL;
    }
    else
    {
        assert(quantumPower <= fractionBits - 1);

        const rounded =
            roundedNormalizedSignificand(
                normalized.numerator,
                normalized.denominator,
                quantumPower);

        assert(!rounded.carry);
        quanta = rounded.value;
    }

    if (quanta == 0)
        return signedZero(exact.negative);

    const real value =
        ldexp(
            cast(real)quanta,
            minSubnormalExponent);

    return exact.negative ? -value : value;
}

private ExactRatio192 exactProduct(
    RealExact lhs,
    RealExact rhs,
    ulong scaleNumerator,
    ulong scaleDenominator)
    @safe pure nothrow @nogc
{
    ulong x = lhs.significand;
    ulong y = rhs.significand;
    ulong n = scaleNumerator;
    ulong d = scaleDenominator;

    cancel(x, d);
    cancel(y, d);
    cancel(n, d);

    const xy = multiply64(x, y);
    const numerator =
        multiply128By64(xy, n);

    assert(bitLength(numerator)
        <= 2 * real.mant_dig + 63);

    return ExactRatio192(
        numerator,
        fromUlong(d),
        lhs.exponent2 + rhs.exponent2,
        lhs.negative != rhs.negative);
}

private ExactRatio192 exactQuotient(
    RealExact lhs,
    RealExact rhs,
    ulong scaleNumerator,
    ulong scaleDenominator)
    @safe pure nothrow @nogc
{
    ulong x = lhs.significand;
    ulong y = rhs.significand;
    ulong n = scaleNumerator;
    ulong d = scaleDenominator;

    cancel(x, y);
    cancel(x, d);
    cancel(n, y);
    cancel(n, d);

    const numerator = multiply64(x, n);
    const denominator = multiply64(y, d);

    assert(bitLength(numerator)
        <= real.mant_dig + 63);
    assert(bitLength(denominator)
        <= real.mant_dig + 63);

    return ExactRatio192(
        numerator,
        denominator,
        lhs.exponent2 - rhs.exponent2,
        lhs.negative != rhs.negative);
}

real rescaleProductReal(
    real lhs,
    real rhs,
    long numerator,
    long denominator)
    @safe pure nothrow @nogc
{
    assert(numerator > 0);
    assert(denominator > 0);

    if (lhs == 0.0L
        || rhs == 0.0L
        || lhs != lhs
        || rhs != rhs
        || lhs == real.infinity
        || lhs == -real.infinity
        || rhs == real.infinity
        || rhs == -real.infinity)
    {
        return lhs * rhs;
    }

    return quantize(
        exactProduct(
            decomposeReal(lhs),
            decomposeReal(rhs),
            cast(ulong)numerator,
            cast(ulong)denominator));
}

real rescaleQuotientReal(
    real lhs,
    real rhs,
    long numerator,
    long denominator)
    @safe pure nothrow @nogc
{
    assert(numerator > 0);
    assert(denominator > 0);

    if (lhs == 0.0L
        || rhs == 0.0L
        || lhs != lhs
        || rhs != rhs
        || lhs == real.infinity
        || lhs == -real.infinity
        || rhs == real.infinity
        || rhs == -real.infinity)
    {
        return lhs / rhs;
    }

    return quantize(
        exactQuotient(
            decomposeReal(lhs),
            decomposeReal(rhs),
            cast(ulong)numerator,
            cast(ulong)denominator));
}
