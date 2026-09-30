module r15_real_identity_conversion;

import core.stdc.string : memcpy;
import std.math : frexp, ldexp;

enum R15RealStatus
{
    exact,
    inexact,
    overflow,
    nonFinite
}

struct RealParts
{
    ulong significand;
    int exponent2;
    bool negative;
    bool zero;
    bool finite;
}

struct RealResult
{
    R15RealStatus status;
    real value;
}

struct DoubleResult
{
    R15RealStatus status;
    double value;
}

struct LongResult
{
    R15RealStatus status;
    long value;
}

private ulong doubleBits(double value)
{
    ulong bits;
    memcpy(&bits, &value, double.sizeof);
    return bits;
}

private double doubleFromBits(ulong bits)
{
    double value;
    memcpy(&value, &bits, double.sizeof);
    return value;
}

private double forceDouble(double value)
{
    return doubleFromBits(doubleBits(value));
}

private RealParts decomposeDouble(double value)
{
    const bits = doubleBits(value);
    const negative = (bits >> 63) != 0;
    const exp = (bits >> 52) & 0x7ffUL;
    const frac = bits & 0x000f_ffff_ffff_ffffUL;

    if (exp == 0x7ffUL)
        return RealParts(0, 0, negative, false, false);

    if (exp == 0)
        return RealParts(frac, -1074, negative, frac == 0, true);

    return RealParts(
        (1UL << 52) | frac,
        cast(int)exp - 1075,
        negative,
        false,
        true);
}

RealParts decomposeReal(real value)
{
    if (value != value)
        return RealParts(0, 0, false, false, false);

    if (value == real.infinity)
        return RealParts(0, 0, false, false, false);

    if (value == -real.infinity)
        return RealParts(0, 0, true, false, false);

    if (value == 0.0L)
    {
        const negative = (1.0L / value) == -real.infinity;
        return RealParts(0, 0, negative, true, true);
    }

    int exponent;
    real fraction = frexp(value, exponent);
    const negative = fraction < 0.0L;

    if (negative)
        fraction = -fraction;

    static assert(real.mant_dig <= 64,
        "Probe 6 is limited to the currently qualified <=64-bit real formats.");

    const real scaled = ldexp(fraction, real.mant_dig);
    const ulong significand = cast(ulong)scaled;

    assert(cast(real)significand == scaled);

    return RealParts(
        significand,
        exponent - real.mant_dig,
        negative,
        false,
        true);
}

private void normalize(ref RealParts x)
{
    if (!x.finite || x.zero)
        return;

    while ((x.significand & 1UL) == 0)
    {
        x.significand >>= 1;
        ++x.exponent2;
    }
}

private bool sameRepresentedValue(RealParts a, RealParts b)
{
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

RealResult longToReal(long source)
{
    const real target = cast(real)source;

    auto parts = decomposeReal(target);
    assert(parts.finite);

    if (source == 0)
        return RealResult(R15RealStatus.exact, target);

    const ulong mag = magnitude(source);

    auto expected = RealParts(
        mag,
        0,
        source < 0,
        false,
        true);

    return RealResult(
        sameRepresentedValue(parts, expected)
            ? R15RealStatus.exact
            : R15RealStatus.inexact,
        target);
}

RealResult doubleToReal(double source)
{
    auto src = decomposeDouble(source);

    if (!src.finite)
        return RealResult(R15RealStatus.nonFinite, real.init);

    const real target = cast(real)source;
    auto dst = decomposeReal(target);

    return RealResult(
        sameRepresentedValue(src, dst)
            ? R15RealStatus.exact
            : R15RealStatus.inexact,
        target);
}

DoubleResult realToDouble(real source)
{
    auto src = decomposeReal(source);

    if (!src.finite)
        return DoubleResult(R15RealStatus.nonFinite, double.init);

    const double target = forceDouble(cast(double)source);
    auto dst = decomposeDouble(target);

    if (!dst.finite)
        return DoubleResult(R15RealStatus.overflow, double.init);

    return DoubleResult(
        sameRepresentedValue(src, dst)
            ? R15RealStatus.exact
            : R15RealStatus.inexact,
        target);
}

LongResult realToLong(real source)
{
    auto x = decomposeReal(source);

    if (!x.finite)
        return LongResult(R15RealStatus.nonFinite, 0);

    if (x.zero)
        return LongResult(R15RealStatus.exact, 0);

    const ulong limit =
        x.negative
        ? cast(ulong)long.max + 1UL
        : cast(ulong)long.max;

    ulong integerMagnitude;
    bool fractional;

    if (x.exponent2 >= 0)
    {
        if (x.exponent2 >= 64)
            return LongResult(R15RealStatus.overflow, 0);

        if (x.significand > (limit >> x.exponent2))
            return LongResult(R15RealStatus.overflow, 0);

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
            return LongResult(R15RealStatus.overflow, 0);
    }

    if (fractional)
        return LongResult(R15RealStatus.inexact, 0);

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

    return LongResult(R15RealStatus.exact, value);
}

real realFromParts(
    ulong significand,
    int exponent2,
    bool negative)
{
    real value = ldexp(cast(real)significand, exponent2);
    return negative ? -value : value;
}

ulong rawDoubleBits(double value)
{
    return doubleBits(value);
}
