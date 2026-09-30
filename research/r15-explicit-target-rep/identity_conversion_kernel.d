module r15_identity_conversion_kernel;

import core.stdc.string : memcpy;

enum R15Status
{
    exact,
    inexact,
    overflow,
    nonFinite
}

struct FloatResult(T)
{
    R15Status status;
    T value;
}

struct LongResult
{
    R15Status status;
    long value;
}

private struct Binary
{
    ulong significand;
    int exponent2;
    bool negative;
    bool zero;
    bool finite;
}

private uint bitsOf(float value)
{
    uint bits;
    memcpy(&bits, &value, float.sizeof);
    return bits;
}

private ulong bitsOf(double value)
{
    ulong bits;
    memcpy(&bits, &value, double.sizeof);
    return bits;
}

private float fromBits(uint bits)
{
    float value;
    memcpy(&value, &bits, float.sizeof);
    return value;
}

private double fromBits(ulong bits)
{
    double value;
    memcpy(&value, &bits, double.sizeof);
    return value;
}

private T forceStorage(T)(T value)
    if (is(T == float) || is(T == double))
{
    static if (is(T == float))
        return fromBits(bitsOf(value));
    else
        return fromBits(bitsOf(value));
}

private Binary decompose(T)(T value)
    if (is(T == float) || is(T == double))
{
    static if (is(T == float))
    {
        const bits = bitsOf(value);
        const negative = (bits >> 31) != 0;
        const exp = (bits >> 23) & 0xffU;
        const frac = bits & 0x7f_ffffU;

        if (exp == 0xffU)
            return Binary(0, 0, negative, false, false);
        if (exp == 0)
            return Binary(frac, -149, negative, frac == 0, true);

        return Binary(
            (1UL << 23) | frac,
            cast(int)exp - 150,
            negative,
            false,
            true);
    }
    else
    {
        const bits = bitsOf(value);
        const negative = (bits >> 63) != 0;
        const exp = (bits >> 52) & 0x7ffUL;
        const frac = bits & 0x000f_ffff_ffff_ffffUL;

        if (exp == 0x7ffUL)
            return Binary(0, 0, negative, false, false);
        if (exp == 0)
            return Binary(frac, -1074, negative, frac == 0, true);

        return Binary(
            (1UL << 52) | frac,
            cast(int)exp - 1075,
            negative,
            false,
            true);
    }
}

private void normalize(ref Binary x)
{
    if (x.zero || !x.finite)
        return;

    while ((x.significand & 1UL) == 0)
    {
        x.significand >>= 1;
        ++x.exponent2;
    }
}

private bool exactSameValue(S, T)(S source, T target)
    if ((is(S == float) || is(S == double)) &&
        (is(T == float) || is(T == double)))
{
    auto a = decompose(source);
    auto b = decompose(target);

    if (!a.finite || !b.finite)
        return false;

    if (a.zero && b.zero)
        return true;

    if (a.zero != b.zero || a.negative != b.negative)
        return false;

    normalize(a);
    normalize(b);

    return a.significand == b.significand
        && a.exponent2 == b.exponent2;
}

private ulong magnitude(long value)
{
    return value >= 0
        ? cast(ulong)value
        : cast(ulong)(-(value + 1)) + 1UL;
}

private bool floatingEqualsLong(T)(T target, long source)
    if (is(T == float) || is(T == double))
{
    auto x = decompose(target);
    if (!x.finite)
        return false;
    if (x.zero)
        return source == 0;
    if (x.negative != (source < 0))
        return false;

    const ulong m = magnitude(source);

    if (x.exponent2 >= 0)
    {
        if (x.exponent2 >= 64)
            return false;

        if (x.significand > (ulong.max >> x.exponent2))
            return false;

        return (x.significand << x.exponent2) == m;
    }

    const int shift = -x.exponent2;
    if (shift >= 64)
        return false;

    const ulong mask =
        shift == 0 ? 0UL : ((1UL << shift) - 1UL);

    if ((x.significand & mask) != 0)
        return false;

    return (x.significand >> shift) == m;
}

FloatResult!T longToFloating(T)(long source)
    if (is(T == float) || is(T == double))
{
    const T target = forceStorage(cast(T)source);

    return FloatResult!T(
        floatingEqualsLong(target, source)
            ? R15Status.exact
            : R15Status.inexact,
        target);
}

FloatResult!T floatingToFloating(S, T)(S source)
    if ((is(S == float) || is(S == double)) &&
        (is(T == float) || is(T == double)))
{
    const auto src = decompose(source);

    if (!src.finite)
        return FloatResult!T(R15Status.nonFinite, T.init);

    const T target = forceStorage(cast(T)source);
    const auto dst = decompose(target);

    if (!dst.finite)
        return FloatResult!T(R15Status.overflow, T.init);

    return FloatResult!T(
        exactSameValue(source, target)
            ? R15Status.exact
            : R15Status.inexact,
        target);
}

LongResult floatingToLong(S)(S source)
    if (is(S == float) || is(S == double))
{
    auto x = decompose(source);

    if (!x.finite)
        return LongResult(R15Status.nonFinite, 0);

    if (x.zero)
        return LongResult(R15Status.exact, 0);

    const ulong limit =
        x.negative
        ? cast(ulong)long.max + 1UL
        : cast(ulong)long.max;

    ulong integerMagnitude;
    bool fractional;

    if (x.exponent2 >= 0)
    {
        if (x.exponent2 >= 64)
            return LongResult(R15Status.overflow, 0);

        if (x.significand > (limit >> x.exponent2))
            return LongResult(R15Status.overflow, 0);

        integerMagnitude = x.significand << x.exponent2;
    }
    else
    {
        const int shift = -x.exponent2;

        if (shift >= 64)
        {
            integerMagnitude = 0;
            fractional = x.significand != 0;
        }
        else
        {
            integerMagnitude = x.significand >> shift;
            const ulong mask =
                shift == 0 ? 0UL : ((1UL << shift) - 1UL);
            fractional = (x.significand & mask) != 0;
        }

        if (integerMagnitude > limit)
            return LongResult(R15Status.overflow, 0);
    }

    if (fractional)
        return LongResult(R15Status.inexact, 0);

    long value;
    if (x.negative)
    {
        value =
            integerMagnitude == cast(ulong)long.max + 1UL
            ? long.min
            : -cast(long)integerMagnitude;
    }
    else
    {
        value = cast(long)integerMagnitude;
    }

    return LongResult(R15Status.exact, value);
}

uint floatBits(float value) { return bitsOf(value); }
ulong doubleBits(double value) { return bitsOf(value); }
float floatFromBits(uint bits) { return fromBits(bits); }
double doubleFromBits(ulong bits) { return fromBits(bits); }
