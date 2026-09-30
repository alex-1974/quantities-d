module r15_rescale_kernel;

import std.traits : Unqual, isIntegral;
import std.math : frexp, ldexp;

import core.stdc.string : memcpy;

// Research adaptation of quantities.binary32_scale at develop b592858.
// Production is unchanged. Target range is classified before quantization.

private:
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

private ulong magnitude(long x) @safe pure nothrow @nogc
{
    return x < 0 ? cast(ulong)(-(x + 1)) + 1UL : cast(ulong)x;
}

private int compareScaled(U128 a, int ae, U128 b, int be)
    @safe pure nothrow @nogc
{
    const ab = bitLength(a);
    const bb = bitLength(b);
    if (ab + ae != bb + be)
        return ab + ae < bb + be ? -1 : 1;
    if (ae < be)
        return compare(a, shiftLeft(b, be - ae));
    return compare(shiftLeft(a, ae - be), b);
}

private ulong roundedSignificand(
    U128 a, U128 b, int fractionBits, out bool exact)
    @safe pure nothrow @nogc
{
    assert(fractionBits >= 0 && fractionBits <= 52);
    ulong result = 1UL << fractionBits;
    U128 remainder = subtract(a, b);
    foreach (i; 0 .. fractionBits)
    {
        remainder = shiftLeft(remainder, 1);
        if (compare(remainder, b) >= 0)
        {
            result |= 1UL << (fractionBits - 1 - i);
            remainder = subtract(remainder, b);
        }
    }
    exact = bitLength(remainder) == 0;
    const cmp = compare(shiftLeft(remainder, 1), b);
    if (cmp > 0 || (cmp == 0 && (result & 1) != 0))
        ++result;
    return result;
}

public:
enum Status { exact, inexact, overflow, nonFinite }
struct Result(T) { Status status; T value; }

T fromBits(T)(ulong bits) @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
{
    T value;
    static if (is(T == float))
    {
        uint small = cast(uint)bits;
        // Copy equal-size scalar storage; both locals live for the call.
        () @trusted { memcpy(&value, &small, T.sizeof); }();
    }
    else
        () @trusted { memcpy(&value, &bits, T.sizeof); }();
    return value;
}

ulong storedBits(T)(T value) @safe pure nothrow @nogc
    if (is(Unqual!T == float) || is(Unqual!T == double))
{
    ulong bits = 0;
    static if (is(Unqual!T == float))
    {
        uint small;
        () @trusted { memcpy(&small, &value, float.sizeof); }();
        return small;
    }
    else
        () @trusted { memcpy(&bits, &value, double.sizeof); }();
    return bits;
}

Result!T convertExact(T)(
    ulong significand, int exponent2, bool negative,
    long numerator, long denominator) @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
{
    assert(denominator > 0);
    enum p = is(T == float) ? 24 : 53;
    enum emin = is(T == float) ? -126 : -1022;
    enum emax = is(T == float) ? 127 : 1023;
    enum sub = emin - (p - 1);
    enum bias = is(T == float) ? 127 : 1023;
    enum signShift = is(T == float) ? 31 : 63;
    const sign = (negative != (numerator < 0)) ? 1UL << signShift : 0UL;

    if (significand == 0 || numerator == 0)
        return Result!T(Status.exact, fromBits!T(sign));

    ulong s = significand;
    ulong n = magnitude(numerator);
    ulong d = cast(ulong)denominator;
    cancel(s, d);
    cancel(n, d);
    const a = multiply64(s, n);
    const b = fromUlong(d);
    assert(bitLength(a) <= 127);

    const maxBound = multiply64((1UL << p) - 1UL, d);
    if (compareScaled(a, exponent2, maxBound, emax - (p - 1)) > 0)
        return Result!T(Status.overflow, T.init);

    const r = normalize(a, b);
    int e = exponent2 + r.exponent2;
    bool exact;
    ulong bits;
    if (e >= emin)
    {
        ulong sig = roundedSignificand(r.numerator, r.denominator, p - 1, exact);
        if (sig == (1UL << p))
        {
            sig >>= 1;
            ++e;
        }
        bits = (cast(ulong)(e + bias) << (p - 1)) | (sig - (1UL << (p - 1)));
    }
    else
    {
        const power = e - sub;
        if (power < -1)
            bits = 0;
        else if (power == -1)
            bits = compare(r.numerator, r.denominator) == 0 ? 0UL : 1UL;
        else
            bits = roundedSignificand(r.numerator, r.denominator, power, exact);
        // Subnormal quanta also encode the carry into the minimum normal.
    }
    return Result!T(exact ? Status.exact : Status.inexact, fromBits!T(sign | bits));
}

Result!T convert(T, S)(S value, long numerator, long denominator)
    @safe pure nothrow @nogc
    if ((is(T == float) || is(T == double)) &&
        (isIntegral!(Unqual!S) || is(Unqual!S == float) ||
         is(Unqual!S == double) || is(Unqual!S == real)))
{
    static if (isIntegral!(Unqual!S))
    {
        static if (is(Unqual!S == ulong))
            return convertExact!T(value, 0, false, numerator, denominator);
        else
            return convertExact!T(magnitude(cast(long)value), 0, value < 0,
                numerator, denominator);
    }
    else static if (is(Unqual!S == float) || is(Unqual!S == double))
    {
        enum p = is(Unqual!S == float) ? 24 : 53;
        enum expBits = is(Unqual!S == float) ? 8 : 11;
        enum bias = is(Unqual!S == float) ? 127 : 1023;
        enum signShift = is(Unqual!S == float) ? 31 : 63;
        const raw = storedBits(value);
        const ef = (raw >> (p - 1)) & ((1UL << expBits) - 1UL);
        if (ef == ((1UL << expBits) - 1UL))
            return Result!T(Status.nonFinite, T.init);
        const fraction = raw & ((1UL << (p - 1)) - 1UL);
        const sig = ef == 0 ? fraction : fraction | (1UL << (p - 1));
        const e = ef == 0 ? 1 - bias - (p - 1) : cast(int)ef - bias - (p - 1);
        return convertExact!T(sig, e, (raw >> signShift) != 0, numerator, denominator);
    }
    else
    {
        static assert((real.mant_dig == 64 && real.min_exp == -16381 &&
                       real.max_exp == 16384) ||
                      (real.mant_dig == 53 && real.min_exp == -1021 &&
                       real.max_exp == 1024));
        if (value != value || value > real.max || value < -real.max)
            return Result!T(Status.nonFinite, T.init);
        // Handle signed zero without reading real's ABI layout.
        if (value == 0)
            return convertExact!T(0, 0, 1.0L / value < 0, numerator, denominator);
        int e;
        const f = frexp(value < 0 ? -value : value, e);
        const sig = cast(ulong)ldexp(f, real.mant_dig);
        return convertExact!T(sig, e - real.mant_dig, value < 0, numerator, denominator);
    }
}

