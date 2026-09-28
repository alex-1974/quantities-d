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


private template ScaleShape(alias S, ulong Factor)
{
    static if (Factor == 0)
        enum ScaleShape = Shape(0, 0);
    else
    {
        // ceil(log2(Factor + 1)): number of value bits required by Factor.
        private enum factorBits = (){
            size_t bitsRequired;
            ulong value = Factor;
            while (value != 0)
            {
                ++bitsRequired;
                value >>= 1;
            }
            return bitsRequired;
        }();

        // Multiplying a range endpoint by Factor can require at most
        // factorBits additional magnitude bits. This is deliberately a
        // range-safe upper bound; SelectRep may therefore be conservative
        // for some non-power-of-two factors, never unsafe.
        enum ScaleShape = Shape(
            S.minPow == 0 ? 0 : S.minPow + factorBits,
            S.maxBits + factorBits);
    }
}

/// Smallest built-in integral Rep that safely contains every value of
/// A * B * Factor. Returns void when no built-in Rep can satisfy that
/// total-range contract.
///
/// Factor is a non-negative compile-time integer scale multiplier.
template ScaledMulRep(A, B, ulong Factor)
{
    static assert(isIntegral!A && isIntegral!B);

    static if (Factor == 0)
        alias ScaledMulRep = ubyte;
    else static if (Factor == 1)
        alias ScaledMulRep = MulRep!(A, B);
    else
        alias ScaledMulRep = SelectRep!(
            ScaleShape!(MulShape!(A, B), Factor));
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
