module app;

import std.traits : isIntegral, isSigned;

template Bits(T)
{
    enum Bits = T.sizeof * 8;
}

template ValueBits(T)
{
    enum ValueBits = Bits!T - (isSigned!T ? 1 : 0);
}

template SignedForBits(size_t valueBits)
{
    static if (valueBits <= 7) alias SignedForBits = byte;
    else static if (valueBits <= 15) alias SignedForBits = short;
    else static if (valueBits <= 31) alias SignedForBits = int;
    else static if (valueBits <= 63) alias SignedForBits = long;
    else alias SignedForBits = void;
}

template UnsignedForBits(size_t valueBits)
{
    static if (valueBits <= 8) alias UnsignedForBits = ubyte;
    else static if (valueBits <= 16) alias UnsignedForBits = ushort;
    else static if (valueBits <= 32) alias UnsignedForBits = uint;
    else static if (valueBits <= 64) alias UnsignedForBits = ulong;
    else alias UnsignedForBits = void;
}

template AddSubRep(A, B)
{
    static assert(isIntegral!A && isIntegral!B);
    static if (Bits!A > 32 || Bits!B > 32)
        alias AddSubRep = void;
    else
    {
        enum signedResult = isSigned!A || isSigned!B;
        enum aPos = ValueBits!A;
        enum bPos = ValueBits!B;
        enum positiveBits = (aPos > bPos ? aPos : bPos) + 1;

        static if (signedResult)
            alias AddSubRep = SignedForBits!positiveBits;
        else
            alias AddSubRep = UnsignedForBits!positiveBits;
    }
}

template MulRep(A, B)
{
    static assert(isIntegral!A && isIntegral!B);
    static if (Bits!A > 32 || Bits!B > 32)
        alias MulRep = void;
    else
    {
        enum signedResult = isSigned!A || isSigned!B;
        enum valueBits = ValueBits!A + ValueBits!B;
        static if (signedResult)
            alias MulRep = SignedForBits!valueBits;
        else
            alias MulRep = UnsignedForBits!valueBits;
    }
}

static assert(is(AddSubRep!(byte, byte) == short));
static assert(is(AddSubRep!(ubyte, ubyte) == ushort));
static assert(is(AddSubRep!(byte, ubyte) == short));
static assert(is(AddSubRep!(short, short) == int));
static assert(is(AddSubRep!(ushort, ushort) == uint));
static assert(is(AddSubRep!(short, ushort) == int));
static assert(is(AddSubRep!(int, int) == long));
static assert(is(AddSubRep!(uint, uint) == ulong));
static assert(is(AddSubRep!(int, uint) == long));
static assert(is(AddSubRep!(long, int) == void));

static assert(is(MulRep!(byte, byte) == short));
static assert(is(MulRep!(ubyte, ubyte) == ushort));
static assert(is(MulRep!(short, short) == int));
static assert(is(MulRep!(ushort, ushort) == uint));
static assert(is(MulRep!(int, int) == long));
static assert(is(MulRep!(uint, uint) == ulong));
static assert(is(MulRep!(int, uint) == long));
static assert(is(MulRep!(long, int) == void));

struct Length {}

struct Q(Spec, Rep)
{
    Rep value;

    auto opBinary(string op, R2)(Q!(Spec, R2) rhs) const
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") &&
            !is(AddSubRep!(Rep, R2) == void))
    {
        alias RR = AddSubRep!(Rep, R2);
        static if (op == "+")
            return Q!(Spec, RR)(cast(RR)value + cast(RR)rhs.value);
        else
            return Q!(Spec, RR)(cast(RR)value - cast(RR)rhs.value);
    }

    auto opBinary(string op, S)(S scalar) const
        @safe pure nothrow @nogc
        if (op == "*" && isIntegral!S &&
            !is(MulRep!(Rep, S) == void))
    {
        alias RR = MulRep!(Rep, S);
        return Q!(Spec, RR)(cast(RR)value * cast(RR)scalar);
    }

    auto opBinaryRight(string op, S)(S scalar) const
        @safe pure nothrow @nogc
        if (op == "*" && isIntegral!S &&
            !is(MulRep!(Rep, S) == void))
    {
        alias RR = MulRep!(Rep, S);
        return Q!(Spec, RR)(cast(RR)scalar * cast(RR)value);
    }
}

@safe pure nothrow @nogc
auto attributeProbe()
{
    Q!(Length, int) a = Q!(Length, int)(10);
    Q!(Length, uint) b = Q!(Length, uint)(20);
    auto sum = a + b;
    auto diff = a - b;
    auto product = a * uint(3);
    auto reverse = uint(3) * a;
    return sum.value + diff.value + product.value + reverse.value;
}

enum ctfe = attributeProbe();
static assert(ctfe == 80);

static assert(is(typeof(Q!(Length, int)(1) + Q!(Length, uint)(2))
    == Q!(Length, long)));
static assert(is(typeof(Q!(Length, uint)(2) * uint(3))
    == Q!(Length, ulong)));
static assert(is(typeof(uint(3) * Q!(Length, uint)(2))
    == Q!(Length, ulong)));

static assert(!__traits(compiles,
    Q!(Length, long)(1) + Q!(Length, int)(2)));
static assert(!__traits(compiles,
    Q!(Length, long)(1) * int(2)));

void main() {}
