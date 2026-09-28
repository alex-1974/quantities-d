module app;

import std.traits : isIntegral, isSigned;

enum bits(T) = T.sizeof * 8;
enum posBits(T) = bits!T - (isSigned!T ? 1 : 0);
enum negPow(T) = isSigned!T ? bits!T - 1 : 0;

struct Shape { size_t minPow; size_t maxBits; }

enum sumMaxBits(size_t a, size_t b) = (a > b ? a : b) + 1;
enum productMaxBits(size_t a, size_t b) = a + b;

template AddShape(A, B)
{
    static if (isSigned!A && isSigned!B)
        enum AddShape = Shape(
            negPow!A == negPow!B
                ? negPow!A + 1
                : (negPow!A > negPow!B ? negPow!A + 1 : negPow!B + 1),
            sumMaxBits!(posBits!A, posBits!B));
    else static if (!isSigned!A && !isSigned!B)
        enum AddShape = Shape(0, sumMaxBits!(posBits!A, posBits!B));
    else static if (isSigned!A)
        enum AddShape = Shape(negPow!A, sumMaxBits!(posBits!A, posBits!B));
    else
        enum AddShape = Shape(negPow!B, sumMaxBits!(posBits!A, posBits!B));
}

template SubShape(A, B)
{
    static if (isSigned!A && isSigned!B)
        enum SubShape = Shape(
            negPow!A >= posBits!B ? negPow!A + 1 : posBits!B + 1,
            posBits!A >= negPow!B ? posBits!A + 1 : negPow!B + 1);
    else static if (!isSigned!A && !isSigned!B)
        enum SubShape = Shape(posBits!B, posBits!A);
    else static if (isSigned!A)
        enum SubShape = Shape(
            negPow!A >= posBits!B ? negPow!A + 1 : posBits!B + 1,
            posBits!A);
    else
        enum SubShape = Shape(
            posBits!B,
            posBits!A >= negPow!B ? posBits!A + 1 : negPow!B + 1);
}

template MulShape(A, B)
{
    static if (!isSigned!A && !isSigned!B)
        enum MulShape = Shape(0, productMaxBits!(posBits!A, posBits!B));
    else static if (isSigned!A && isSigned!B)
        enum MulShape = Shape(
            negPow!A + posBits!B,
            negPow!A + negPow!B + 1);
    else static if (isSigned!A)
        enum MulShape = Shape(
            negPow!A + posBits!B,
            posBits!A + posBits!B);
    else
        enum MulShape = Shape(
            posBits!A + negPow!B,
            posBits!A + posBits!B);
}

template FitsShape(T, alias S)
{
    static if (isSigned!T)
        enum FitsShape = S.minPow <= bits!T - 1 && S.maxBits <= bits!T - 1;
    else
        enum FitsShape = S.minPow == 0 && S.maxBits <= bits!T;
}

template SelectRep(alias S)
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

template AddRep(A,B) { alias AddRep = SelectRep!(AddShape!(A,B)); }
template SubRep(A,B) { alias SubRep = SelectRep!(SubShape!(A,B)); }
template MulRep(A,B) { alias MulRep = SelectRep!(MulShape!(A,B)); }

struct Length {}

struct Q(Spec, Rep)
{
    Rep value;

    auto opBinary(string op, R)(Q!(Spec, R) rhs) const
        @safe pure nothrow @nogc
        if (op == "+" && !is(AddRep!(Rep,R) == void))
    {
        alias RR = AddRep!(Rep,R);
        return Q!(Spec,RR)(cast(RR)value + cast(RR)rhs.value);
    }

    auto opBinary(string op, R)(Q!(Spec, R) rhs) const
        @safe pure nothrow @nogc
        if (op == "-" && !is(SubRep!(Rep,R) == void))
    {
        alias RR = SubRep!(Rep,R);
        return Q!(Spec,RR)(cast(RR)value - cast(RR)rhs.value);
    }

    auto opBinary(string op, S)(S scalar) const
        @safe pure nothrow @nogc
        if (op == "*" && isIntegral!S && !is(MulRep!(Rep,S) == void))
    {
        alias RR = MulRep!(Rep,S);
        return Q!(Spec,RR)(cast(RR)value * cast(RR)scalar);
    }

    auto opBinaryRight(string op, S)(S scalar) const
        @safe pure nothrow @nogc
        if (op == "*" && isIntegral!S && !is(MulRep!(Rep,S) == void))
    {
        alias RR = MulRep!(Rep,S);
        return Q!(Spec,RR)(cast(RR)scalar * cast(RR)value);
    }
}

static assert(is(AddRep!(int,int) == long));
static assert(is(SubRep!(uint,uint) == long));
static assert(is(MulRep!(uint,uint) == ulong));
static assert(is(AddRep!(long,byte) == void));
static assert(is(MulRep!(long,int) == void));

enum addMax = Q!(Length,int)(int.max) + Q!(Length,int)(int.max);
static assert(is(typeof(addMax) == Q!(Length,long)));
static assert(addMax.value == cast(long)int.max + cast(long)int.max);

enum addMin = Q!(Length,int)(int.min) + Q!(Length,int)(int.min);
static assert(addMin.value == cast(long)int.min + cast(long)int.min);

enum unsignedDiffLow = Q!(Length,uint)(0) - Q!(Length,uint)(uint.max);
static assert(is(typeof(unsignedDiffLow) == Q!(Length,long)));
static assert(unsignedDiffLow.value == -cast(long)uint.max);

enum unsignedDiffHigh = Q!(Length,uint)(uint.max) - Q!(Length,uint)(0);
static assert(unsignedDiffHigh.value == cast(long)uint.max);

enum unsignedProduct =
    Q!(Length,uint)(uint.max) * uint.max;
static assert(is(typeof(unsignedProduct) == Q!(Length,ulong)));
static assert(unsignedProduct.value ==
    cast(ulong)uint.max * cast(ulong)uint.max);

enum signedProduct =
    Q!(Length,int)(int.min) * int.min;
static assert(is(typeof(signedProduct) == Q!(Length,long)));
static assert(signedProduct.value ==
    cast(long)int.min * cast(long)int.min);

enum reverseProduct =
    uint.max * Q!(Length,uint)(uint.max);
static assert(reverseProduct.value == unsignedProduct.value);

static assert(!__traits(compiles,
    Q!(Length,long)(long.max) + Q!(Length,byte)(1)));
static assert(!__traits(compiles,
    Q!(Length,long)(long.min) - Q!(Length,int)(1)));
static assert(!__traits(compiles,
    Q!(Length,long)(long.max) * int(2)));
static assert(!__traits(compiles,
    ulong.max * Q!(Length,uint)(1)));

@safe pure nothrow @nogc
long attributeProbe()
{
    auto a = Q!(Length,int)(int.max);
    auto b = Q!(Length,int)(1);
    auto c = a + b;
    auto d = Q!(Length,uint)(uint.max) - Q!(Length,uint)(0);
    return c.value + d.value;
}

enum ctfe = attributeProbe();
static assert(ctfe ==
    cast(long)int.max + 1L + cast(long)uint.max);

void main() {}
