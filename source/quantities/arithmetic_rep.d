module quantities.arithmetic_rep;

import std.traits : isFloatingPoint, isIntegral, isSigned;

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

/*
 * Floating arithmetic admission is separate from the integral range
 * selectors above. Integral/integral combinations continue to delegate to
 * the established AddRep/SubRep contracts unchanged.
 *
 * For mixed integral/floating arithmetic, admit the native floating result
 * only when every value of the integral operand Rep is exactly representable
 * by that floating ResultRep. This prevents operand information loss before
 * the arithmetic operation itself. Ordinary floating result rounding remains
 * native floating semantics after admission.
 */
private enum integralValueBits(T) =
    bits!T - (isSigned!T ? 1 : 0);

private template FloatingBinaryRep(A, B)
{
    static if (isFloatingPoint!A && isFloatingPoint!B)
        alias FloatingBinaryRep = typeof(A.init + B.init);
    else static if (
        isIntegral!A &&
        !is(A == bool) &&
        isFloatingPoint!B)
    {
        alias Candidate = typeof(A.init + B.init);
        static if (integralValueBits!A <= Candidate.mant_dig)
            alias FloatingBinaryRep = Candidate;
        else
            alias FloatingBinaryRep = void;
    }
    else static if (
        isFloatingPoint!A &&
        isIntegral!B &&
        !is(B == bool))
    {
        alias Candidate = typeof(A.init + B.init);
        static if (integralValueBits!B <= Candidate.mant_dig)
            alias FloatingBinaryRep = Candidate;
        else
            alias FloatingBinaryRep = void;
    }
    else
        alias FloatingBinaryRep = void;
}

template AddArithmeticRep(A, B)
{
    static if (isIntegral!A && isIntegral!B)
        alias AddArithmeticRep = AddRep!(A, B);
    else
        alias AddArithmeticRep = FloatingBinaryRep!(A, B);
}

template SubArithmeticRep(A, B)
{
    static if (isIntegral!A && isIntegral!B)
        alias SubArithmeticRep = SubRep!(A, B);
    else
        alias SubArithmeticRep = FloatingBinaryRep!(A, B);
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


private ulong positiveMax(T)() @safe pure nothrow @nogc
    if (isIntegral!T)
{
    return cast(ulong)T.max;
}

private ulong negativeMagnitudeMax(T)() @safe pure nothrow @nogc
    if (isIntegral!T)
{
    static if (isSigned!T)
        return magnitude(cast(long)T.min);
    else
        return 0;
}

private bool scaledMagnitudeFits(
    ulong sourceMagnitude,
    ulong numerator,
    ulong denominator,
    ulong resultMagnitudeLimit) @safe pure nothrow @nogc
{
    assert(numerator > 0);
    assert(denominator > 0);
    return compare(
        multiply64(sourceMagnitude, numerator),
        multiply64(resultMagnitudeLimit, denominator)) <= 0;
}

private template ExactQuotientEnvelope(
    Lhs, Rhs, ulong Numerator, ulong Denominator)
{
    static assert(isIntegral!Lhs && isIntegral!Rhs);
    static assert(Numerator > 0 && Denominator > 0);

    enum lhsPositive = positiveMax!Lhs;
    enum lhsNegative = negativeMagnitudeMax!Lhs;

    static if (isSigned!Lhs && isSigned!Rhs)
        enum positiveSourceMagnitude =
            lhsNegative > lhsPositive ? lhsNegative : lhsPositive;
    else
        enum positiveSourceMagnitude = lhsPositive;

    static if (isSigned!Lhs)
        enum negativeFromLhs = lhsNegative;
    else
        enum negativeFromLhs = 0UL;

    static if (isSigned!Rhs)
        enum negativeFromRhs = lhsPositive;
    else
        enum negativeFromRhs = 0UL;

    enum negativeSourceMagnitude =
        negativeFromLhs > negativeFromRhs
            ? negativeFromLhs
            : negativeFromRhs;
    enum hasNegative = negativeSourceMagnitude != 0;
}

private template ExactQuotientEnvelopeFits(
    Lhs, Rhs, ulong Numerator, ulong Denominator, Candidate)
{
    alias Env = ExactQuotientEnvelope!(
        Lhs, Rhs, Numerator, Denominator);

    enum positiveFits = scaledMagnitudeFits(
        Env.positiveSourceMagnitude,
        Numerator,
        Denominator,
        positiveMax!Candidate);

    static if (Env.hasNegative)
    {
        static if (isSigned!Candidate)
            enum negativeFits = scaledMagnitudeFits(
                Env.negativeSourceMagnitude,
                Numerator,
                Denominator,
                negativeMagnitudeMax!Candidate);
        else
            enum negativeFits = false;
    }
    else
        enum negativeFits = true;

    enum ExactQuotientEnvelopeFits = positiveFits && negativeFits;
}

/// Smallest built-in integral Rep that contains every exact mathematical
/// result of (Lhs * Numerator) / (Rhs * Denominator) for nonzero Rhs.
///
/// Division by zero and integral exactness remain runtime semantic checks.
/// Result-range safety is a compile-time gate.
template ExactQuotientResultRep(
    Lhs, Rhs, ulong Numerator, ulong Denominator)
{
    static assert(isIntegral!Lhs && isIntegral!Rhs);
    static assert(Numerator > 0 && Denominator > 0);

    static if (ExactQuotientEnvelopeFits!(
        Lhs, Rhs, Numerator, Denominator, ubyte))
        alias ExactQuotientResultRep = ubyte;
    else static if (ExactQuotientEnvelopeFits!(
        Lhs, Rhs, Numerator, Denominator, byte))
        alias ExactQuotientResultRep = byte;
    else static if (ExactQuotientEnvelopeFits!(
        Lhs, Rhs, Numerator, Denominator, ushort))
        alias ExactQuotientResultRep = ushort;
    else static if (ExactQuotientEnvelopeFits!(
        Lhs, Rhs, Numerator, Denominator, short))
        alias ExactQuotientResultRep = short;
    else static if (ExactQuotientEnvelopeFits!(
        Lhs, Rhs, Numerator, Denominator, uint))
        alias ExactQuotientResultRep = uint;
    else static if (ExactQuotientEnvelopeFits!(
        Lhs, Rhs, Numerator, Denominator, int))
        alias ExactQuotientResultRep = int;
    else static if (ExactQuotientEnvelopeFits!(
        Lhs, Rhs, Numerator, Denominator, ulong))
        alias ExactQuotientResultRep = ulong;
    else static if (ExactQuotientEnvelopeFits!(
        Lhs, Rhs, Numerator, Denominator, long))
        alias ExactQuotientResultRep = long;
    else
        alias ExactQuotientResultRep = void;
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

// Dispatcher preserves the existing integral result rules.
static assert(is(AddArithmeticRep!(int, uint) == long));
static assert(is(SubArithmeticRep!(uint, uint) == long));

// Floating/floating follows native D promotion.
static assert(is(AddArithmeticRep!(float, double) == double));
static assert(is(SubArithmeticRep!(double, float) == double));

// Mixed arithmetic is admitted only when the complete integral operand domain
// is exactly representable by the native floating result Rep.
static assert(is(AddArithmeticRep!(short, float) == float));
static assert(is(AddArithmeticRep!(int, double) == double));
static assert(is(SubArithmeticRep!(double, int) == double));
static assert(is(AddArithmeticRep!(int, float) == void));
static assert(is(AddArithmeticRep!(long, double) == void));
static assert(is(SubArithmeticRep!(double, long) == void));
static assert(is(AddArithmeticRep!(bool, double) == void));
static assert(is(SubArithmeticRep!(double, bool) == void));
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


static assert(is(ExactQuotientResultRep!(byte, byte, 1, 1) == short));
static assert(is(ExactQuotientResultRep!(short, short, 1, 1) == int));
static assert(is(ExactQuotientResultRep!(int, int, 1, 1) == long));
static assert(is(ExactQuotientResultRep!(long, long, 1, 1) == void));
static assert(is(ExactQuotientResultRep!(ubyte, ubyte, 1, 1) == ubyte));
static assert(is(ExactQuotientResultRep!(uint, int, 1, 1) == long));
static assert(is(ExactQuotientResultRep!(int, uint, 1, 1) == int));
static assert(is(ExactQuotientResultRep!(int, int, 5, 18) == int));
static assert(is(ExactQuotientResultRep!(byte, byte, 1000, 1) == int));

static assert(is(QuotientRep!(int, uint) == int));
static assert(is(QuotientRep!(int, int) == long));
static assert(is(QuotientRep!(uint, int) == long));
static assert(is(QuotientRep!(long, long) == void));
static assert(is(QuotientRep!(ulong, int) == void));
