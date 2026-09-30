module quantities.binary32_scale;

import core.stdc.string : memcpy;

struct U128
{
    ulong lo;
    ulong hi;
}

struct Binary32Exact
{
    ulong significand;
    int exponent2;
    bool negative;
}

struct ExactRational128
{
    U128 numerator;
    U128 denominator;
    int exponent2;
    bool negative;
}

private uint bitsOf(float value)
    @safe pure nothrow @nogc
{
    uint bits;
    () @trusted {
        memcpy(&bits, &value, float.sizeof);
    }();
    return bits;
}

private float floatFromBits(uint bits)
    @safe pure nothrow @nogc
{
    float value;
    () @trusted {
        memcpy(&value, &bits, float.sizeof);
    }();
    return value;
}

private bool finite(float value)
    @safe pure nothrow @nogc
{
    return ((bitsOf(value) >> 23) & 0xffU) != 0xffU;
}

private bool zero(float value)
    @safe pure nothrow @nogc
{
    return (bitsOf(value) & 0x7fff_ffffU) == 0;
}

private int bitLength(ulong value)
    @safe pure nothrow @nogc
{
    if (value == 0)
        return 0;

    int result;
    while (value != 0)
    {
        ++result;
        value >>= 1;
    }
    return result;
}

private int bitLength(U128 value)
    @safe pure nothrow @nogc
{
    if (value.hi != 0)
        return 64 + bitLength(value.hi);
    return bitLength(value.lo);
}

private int compare(U128 a, U128 b)
    @safe pure nothrow @nogc
{
    if (a.hi < b.hi) return -1;
    if (a.hi > b.hi) return 1;
    if (a.lo < b.lo) return -1;
    if (a.lo > b.lo) return 1;
    return 0;
}

private U128 subtract(U128 a, U128 b)
    @safe pure nothrow @nogc
{
    assert(compare(a, b) >= 0);
    const borrow = a.lo < b.lo ? 1UL : 0UL;
    return U128(
        a.lo - b.lo,
        a.hi - b.hi - borrow);
}

private U128 shiftLeft(U128 value, int shift)
    @safe pure nothrow @nogc
{
    assert(shift >= 0);

    foreach (_; 0 .. shift)
    {
        assert((value.hi & (1UL << 63)) == 0);
        value.hi = (value.hi << 1) | (value.lo >> 63);
        value.lo <<= 1;
    }

    return value;
}

private U128 fromUlong(ulong value)
    @safe pure nothrow @nogc
{
    return U128(value, 0);
}

private U128 multiply64(ulong a, ulong b)
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

    return U128(
        (p00 & mask) | (middle << 32),
        p11
            + (p01 >> 32)
            + (p10 >> 32)
            + (middle >> 32));
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

private Binary32Exact decompose(float value)
    @safe pure nothrow @nogc
{
    const bits = bitsOf(value);
    const negative = (bits >> 31) != 0;
    const exponentField = (bits >> 23) & 0xffU;
    const fraction = bits & 0x007f_ffffU;

    assert(exponentField != 0xffU);

    if (exponentField == 0)
    {
        assert(fraction != 0);
        return Binary32Exact(
            cast(ulong)fraction,
            -149,
            negative);
    }

    return Binary32Exact(
        cast(ulong)((1U << 23) | fraction),
        cast(int)exponentField - 150,
        negative);
}

private struct NormalizedRatio
{
    U128 numerator;
    U128 denominator;
    int exponent2;
}

private NormalizedRatio normalize(
    U128 numerator,
    U128 denominator)
    @safe pure nothrow @nogc
{
    assert(bitLength(numerator) != 0);
    assert(bitLength(denominator) != 0);

    int exponent2 =
        bitLength(numerator)
        - bitLength(denominator);

    U128 a;
    U128 b;

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

private ulong roundedNormalizedSignificand(
    U128 numerator,
    U128 denominator,
    int fractionBits)
    @safe pure nothrow @nogc
{
    assert(fractionBits >= 0 && fractionBits <= 23);
    assert(compare(numerator, denominator) >= 0);

    ulong result = 1UL << fractionBits;
    U128 remainder = subtract(numerator, denominator);

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

    if (cmp > 0 || (cmp == 0 && (result & 1UL) != 0))
        ++result;

    return result;
}

private float quantize(ExactRational128 exact)
    @safe pure nothrow @nogc
{
    assert(bitLength(exact.numerator) != 0);
    assert(bitLength(exact.denominator) != 0);

    const normalized =
        normalize(exact.numerator, exact.denominator);

    int topExponent =
        exact.exponent2
        + normalized.exponent2;

    const signBits =
        exact.negative ? (1U << 31) : 0U;

    if (topExponent > 127)
        return floatFromBits(
            signBits | (0xffU << 23));

    if (topExponent >= -126)
    {
        ulong significand =
            roundedNormalizedSignificand(
                normalized.numerator,
                normalized.denominator,
                23);

        if (significand == (1UL << 24))
        {
            significand >>= 1;
            ++topExponent;

            if (topExponent > 127)
                return floatFromBits(
                    signBits | (0xffU << 23));
        }

        const exponentField =
            cast(uint)(topExponent + 127);

        const fraction =
            cast(uint)(significand - (1UL << 23));

        return floatFromBits(
            signBits
            | (exponentField << 23)
            | fraction);
    }

    const quantumPower =
        topExponent + 149;

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
        assert(quantumPower <= 22);
        quanta =
            roundedNormalizedSignificand(
                normalized.numerator,
                normalized.denominator,
                quantumPower);
    }

    if (quanta == 0)
        return floatFromBits(signBits);

    if (quanta == (1UL << 23))
        return floatFromBits(
            signBits | (1U << 23));

    assert(quanta < (1UL << 23));

    return floatFromBits(
        signBits | cast(uint)quanta);
}

private ExactRational128 exactProduct(
    Binary32Exact lhs,
    Binary32Exact rhs,
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

    const xy = x * y;
    const numerator = multiply64(xy, n);

    assert(bitLength(numerator) <= 111);
    assert(bitLength(d) <= 63);

    return ExactRational128(
        numerator,
        fromUlong(d),
        lhs.exponent2 + rhs.exponent2,
        lhs.negative != rhs.negative);
}

private ExactRational128 exactQuotient(
    Binary32Exact lhs,
    Binary32Exact rhs,
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

    assert(bitLength(numerator) <= 87);
    assert(bitLength(denominator) <= 87);

    return ExactRational128(
        numerator,
        denominator,
        lhs.exponent2 - rhs.exponent2,
        lhs.negative != rhs.negative);
}

float rescaleProductBinary32(
    float lhs,
    float rhs,
    long numerator,
    long denominator)
    @safe pure nothrow @nogc
{
    assert(numerator > 0);
    assert(denominator > 0);

    if (__ctfe)
    {
        assert(false,
            "R04.17: nontrivial binary32 product rescale "
            ~ "requires represented-source runtime semantics");
    }

    if (!finite(lhs)
        || !finite(rhs)
        || zero(lhs)
        || zero(rhs))
    {
        return lhs * rhs;
    }

    return quantize(
        exactProduct(
            decompose(lhs),
            decompose(rhs),
            cast(ulong)numerator,
            cast(ulong)denominator));
}

float rescaleQuotientBinary32(
    float lhs,
    float rhs,
    long numerator,
    long denominator)
    @safe pure nothrow @nogc
{
    assert(numerator > 0);
    assert(denominator > 0);

    if (__ctfe)
    {
        assert(false,
            "R04.17: nontrivial binary32 quotient rescale "
            ~ "requires represented-source runtime semantics");
    }

    if (!finite(lhs)
        || !finite(rhs)
        || zero(lhs)
        || zero(rhs))
    {
        return lhs / rhs;
    }

    return quantize(
        exactQuotient(
            decompose(lhs),
            decompose(rhs),
            cast(ulong)numerator,
            cast(ulong)denominator));
}

uint resultBits(float value)
    @safe pure nothrow @nogc
{
    return bitsOf(value);
}

float inputFromBits(uint bits)
    @safe pure nothrow @nogc
{
    return floatFromBits(bits);
}
