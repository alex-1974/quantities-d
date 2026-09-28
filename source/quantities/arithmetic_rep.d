module quantities.arithmetic_rep;

import std.traits : isIntegral, isSigned;

package(quantities):

private enum bits(T) = T.sizeof * 8;
private enum posBits(T) = bits!T - (isSigned!T ? 1 : 0);
private enum negPow(T) = isSigned!T ? bits!T - 1 : 0;

private struct Shape
{
    size_t minPow;
    size_t maxBits;
}

private enum sumMaxBits(size_t a, size_t b) =
    (a > b ? a : b) + 1;

private enum productMaxBits(size_t a, size_t b) = a + b;

private template AddShape(A, B)
{
    static if (isSigned!A && isSigned!B)
        enum AddShape = Shape(
            negPow!A == negPow!B
                ? negPow!A + 1
                : (negPow!A > negPow!B ? negPow!A + 1 : negPow!B + 1),
            sumMaxBits!(posBits!A, posBits!B)
        );
    else static if (!isSigned!A && !isSigned!B)
        enum AddShape = Shape(0, sumMaxBits!(posBits!A, posBits!B));
    else static if (isSigned!A)
        enum AddShape = Shape(
            negPow!A,
            sumMaxBits!(posBits!A, posBits!B)
        );
    else
        enum AddShape = Shape(
            negPow!B,
            sumMaxBits!(posBits!A, posBits!B)
        );
}

private template SubShape(A, B)
{
    static if (isSigned!A && isSigned!B)
        enum SubShape = Shape(
            negPow!A >= posBits!B ? negPow!A + 1 : posBits!B + 1,
            posBits!A >= negPow!B ? posBits!A + 1 : negPow!B + 1
        );
    else static if (!isSigned!A && !isSigned!B)
        enum SubShape = Shape(posBits!B, posBits!A);
    else static if (isSigned!A)
        enum SubShape = Shape(
            negPow!A >= posBits!B ? negPow!A + 1 : posBits!B + 1,
            posBits!A
        );
    else
        enum SubShape = Shape(
            posBits!B,
            posBits!A >= negPow!B ? posBits!A + 1 : negPow!B + 1
        );
}

private template MulShape(A, B)
{
    static if (!isSigned!A && !isSigned!B)
        enum MulShape = Shape(
            0,
            productMaxBits!(posBits!A, posBits!B)
        );
    else static if (isSigned!A && isSigned!B)
        enum MulShape = Shape(
            negPow!A + posBits!B,
            negPow!A + negPow!B + 1
        );
    else static if (isSigned!A)
        enum MulShape = Shape(
            negPow!A + posBits!B,
            posBits!A + posBits!B
        );
    else
        enum MulShape = Shape(
            posBits!A + negPow!B,
            posBits!A + posBits!B
        );
}

private template FitsShape(T, alias S)
{
    static if (isSigned!T)
        enum FitsShape =
            S.minPow <= bits!T - 1 &&
            S.maxBits <= bits!T - 1;
    else
        enum FitsShape =
            S.minPow == 0 &&
            S.maxBits <= bits!T;
}

private template SelectRep(alias S)
{
    static if (FitsShape!(byte, S)) alias SelectRep = byte;
    else static if (FitsShape!(ubyte, S)) alias SelectRep = ubyte;
    else static if (FitsShape!(short, S)) alias SelectRep = short;
    else static if (FitsShape!(ushort, S)) alias SelectRep = ushort;
    else static if (FitsShape!(int, S)) alias SelectRep = int;
    else static if (FitsShape!(uint, S)) alias SelectRep = uint;
    else static if (FitsShape!(long, S)) alias SelectRep = long;
    else static if (FitsShape!(ulong, S)) alias SelectRep = ulong;
    else alias SelectRep = void;
}

template AddRep(A, B)
{
    static assert(isIntegral!A && isIntegral!B);
    alias AddRep = SelectRep!(AddShape!(A, B));
}

template SubRep(A, B)
{
    static assert(isIntegral!A && isIntegral!B);
    alias SubRep = SelectRep!(SubShape!(A, B));
}

template MulRep(A, B)
{
    static assert(isIntegral!A && isIntegral!B);
    alias MulRep = SelectRep!(MulShape!(A, B));
}


private struct U128
{
    ulong hi;
    ulong lo;
}

private struct S128
{
    bool negative;
    U128 magnitude;
}

private int compare(U128 a, U128 b) @safe pure nothrow @nogc
{
    if (a.hi < b.hi) return -1;
    if (a.hi > b.hi) return 1;
    if (a.lo < b.lo) return -1;
    if (a.lo > b.lo) return 1;
    return 0;
}

private int compare(S128 a, S128 b) @safe pure nothrow @nogc
{
    if (a.negative != b.negative)
        return a.negative ? -1 : 1;

    const c = compare(a.magnitude, b.magnitude);
    return a.negative ? -c : c;
}

private U128 multiply64(ulong a, ulong b) @safe pure nothrow @nogc
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

    const middle = (p00 >> 32) + (p01 & mask) + (p10 & mask);
    return U128(
        p11 + (p01 >> 32) + (p10 >> 32) + (middle >> 32),
        (p00 & mask) | (middle << 32));
}

private ulong magnitude(long value) @safe pure nothrow @nogc
{
    return value < 0
        ? cast(ulong)(-(value + 1)) + 1
        : cast(ulong)value;
}

private S128 signed128(long value) @safe pure nothrow @nogc
{
    return S128(value < 0, U128(0, magnitude(value)));
}

private S128 unsigned128(ulong value) @safe pure nothrow @nogc
{
    return S128(false, U128(0, value));
}

private struct Endpoint
{
    bool negative;
    ulong magnitude;
}

private Endpoint minEndpoint(T)() @safe pure nothrow @nogc
{
    static if (isSigned!T)
        return Endpoint(true, magnitude(cast(long)T.min));
    else
        return Endpoint(false, 0);
}

private Endpoint maxEndpoint(T)() @safe pure nothrow @nogc
{
    return Endpoint(false, cast(ulong)T.max);
}

private S128 multiplyEndpoints(Endpoint a, Endpoint b)
    @safe pure nothrow @nogc
{
    const mag = multiply64(a.magnitude, b.magnitude);
    bool negative = a.negative != b.negative;
    if (mag.hi == 0 && mag.lo == 0)
        negative = false;
    return S128(negative, mag);
}

private S128 min4(S128 a, S128 b, S128 c, S128 d)
    @safe pure nothrow @nogc
{
    auto result = compare(a, b) <= 0 ? a : b;
    result = compare(result, c) <= 0 ? result : c;
    return compare(result, d) <= 0 ? result : d;
}

private S128 max4(S128 a, S128 b, S128 c, S128 d)
    @safe pure nothrow @nogc
{
    auto result = compare(a, b) >= 0 ? a : b;
    result = compare(result, c) >= 0 ? result : c;
    return compare(result, d) >= 0 ? result : d;
}

private struct ExactRange
{
    S128 min;
    S128 max;
}

private ExactRange productRange(A, B)() @safe pure nothrow @nogc
{
    enum amin = minEndpoint!A;
    enum amax = maxEndpoint!A;
    enum bmin = minEndpoint!B;
    enum bmax = maxEndpoint!B;

    enum p1 = multiplyEndpoints(amin, bmin);
    enum p2 = multiplyEndpoints(amin, bmax);
    enum p3 = multiplyEndpoints(amax, bmin);
    enum p4 = multiplyEndpoints(amax, bmax);
    return ExactRange(min4(p1, p2, p3, p4), max4(p1, p2, p3, p4));
}

private ExactRange scaledProductRange(A, B, ulong factor)()
    @safe pure nothrow @nogc
{
    enum range = productRange!(A, B);

    static if (factor == 0)
        return ExactRange(signed128(0), signed128(0));
    else static if (factor == 1)
        return range;
    else
    {
        static assert(
            range.min.magnitude.hi == 0 &&
            range.max.magnitude.hi == 0,
            "ScaledMulRep factor > 1 requires a wider exact range oracle for this operand pair");

        return ExactRange(
            S128(range.min.negative,
                multiply64(range.min.magnitude.lo, factor)),
            S128(range.max.negative,
                multiply64(range.max.magnitude.lo, factor)));
    }
}

private bool contains(T)(ExactRange range) @safe pure nothrow @nogc
{
    static if (isSigned!T)
    {
        enum lo = signed128(cast(long)T.min);
        enum hi = signed128(cast(long)T.max);
        return compare(range.min, lo) >= 0 && compare(range.max, hi) <= 0;
    }
    else
    {
        enum lo = unsigned128(0);
        enum hi = unsigned128(cast(ulong)T.max);
        return compare(range.min, lo) >= 0 && compare(range.max, hi) <= 0;
    }
}

/// Smallest built-in integral Rep containing the complete mathematical range
/// of A * B * Factor.
///
/// Factor 0 and 1 are supported for every built-in integral operand pair.
/// Factor > 1 is currently admitted only when the proven exact 64x64->128
/// oracle can scale both unscaled range endpoints without requiring 128x64
/// multiplication.
template ScaledMulRep(A, B, ulong Factor)
{
    static assert(isIntegral!A && isIntegral!B);
    enum range = scaledProductRange!(A, B, Factor);

    static if (!range.min.negative)
    {
        static if (contains!ubyte(range)) alias ScaledMulRep = ubyte;
        else static if (contains!ushort(range)) alias ScaledMulRep = ushort;
        else static if (contains!uint(range)) alias ScaledMulRep = uint;
        else static if (contains!ulong(range)) alias ScaledMulRep = ulong;
        else alias ScaledMulRep = void;
    }
    else
    {
        static if (contains!byte(range)) alias ScaledMulRep = byte;
        else static if (contains!short(range)) alias ScaledMulRep = short;
        else static if (contains!int(range)) alias ScaledMulRep = int;
        else static if (contains!long(range)) alias ScaledMulRep = long;
        else alias ScaledMulRep = void;
    }
}

template QuotientRep(A, B)
{
    static assert(isIntegral!A && isIntegral!B);

    static if (!isSigned!B)
        alias QuotientRep = A;
    else static if (A.sizeof < long.sizeof)
    {
        static if (A.sizeof == 1)
            alias QuotientRep = short;
        else static if (A.sizeof == 2)
            alias QuotientRep = int;
        else
            alias QuotientRep = long;
    }
    else
        alias QuotientRep = void;
}

static assert(is(AddRep!(int, uint) == long));
static assert(is(SubRep!(uint, uint) == long));
static assert(is(MulRep!(uint, uint) == ulong));
static assert(is(AddRep!(long, long) == void));
static assert(is(MulRep!(ulong, ulong) == void));

enum max64Square = multiply64(ulong.max, ulong.max);
static assert(max64Square.hi == ulong.max - 1);
static assert(max64Square.lo == 1);

static assert(is(ScaledMulRep!(byte, byte, 1) == short));
static assert(is(ScaledMulRep!(ubyte, ubyte, 1) == ushort));
static assert(is(ScaledMulRep!(int, int, 1) == long));
static assert(is(ScaledMulRep!(uint, uint, 1) == ulong));
static assert(is(ScaledMulRep!(long, long, 1) == void));
static assert(is(ScaledMulRep!(long, long, 0) == ubyte));

// Scaling may require a wider result than the unscaled product.
static assert(is(ScaledMulRep!(byte, byte, 1000) == int));

static assert(is(QuotientRep!(int, uint) == int));
static assert(is(QuotientRep!(int, int) == long));
static assert(is(QuotientRep!(uint, int) == long));
static assert(is(QuotientRep!(long, long) == void));
static assert(is(QuotientRep!(ulong, int) == void));
