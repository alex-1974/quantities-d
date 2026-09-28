module app;

import std.traits : isIntegral, isSigned;

// ---------- semantic layer ----------

struct LengthDimension {}
struct Metre {}

struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
    enum closedAdditiveValue = true;
    enum scalableValue = true;
}

struct Radius
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

template hasClosedAdditiveValue(Spec)
{
    static if (__traits(hasMember, Spec, "closedAdditiveValue"))
        enum hasClosedAdditiveValue =
            is(typeof(Spec.closedAdditiveValue) == bool) &&
            Spec.closedAdditiveValue;
    else
        enum hasClosedAdditiveValue = false;
}

template isScalableValue(Spec)
{
    static if (__traits(hasMember, Spec, "scalableValue"))
        enum isScalableValue =
            is(typeof(Spec.scalableValue) == bool) &&
            Spec.scalableValue;
    else
        enum isScalableValue = false;
}

template AddResult(Lhs, Rhs)
{
    static if (is(Lhs == Rhs) && hasClosedAdditiveValue!Lhs)
        alias AddResult = Lhs;
    else
        alias AddResult = void;
}

template SubResult(Lhs, Rhs)
{
    static if (is(Lhs == Rhs) && hasClosedAdditiveValue!Lhs)
        alias SubResult = Lhs;
    else
        alias SubResult = void;
}

// ---------- representation layer ----------

enum bits(T) = T.sizeof * 8;
enum posBits(T) = bits!T - (isSigned!T ? 1 : 0);
enum negPow(T) = isSigned!T ? bits!T - 1 : 0;

struct Shape
{
    size_t minPow;
    size_t maxBits;
}

enum maxSize(size_t a, size_t b) = a > b ? a : b;
enum sumMaxBits(size_t a, size_t b) = maxSize!(a, b) + 1;
enum productMaxBits(size_t a, size_t b) = a + b;

template AddShape(A, B)
{
    static if (isSigned!A && isSigned!B)
        enum AddShape = Shape(
            negPow!A == negPow!B
                ? negPow!A + 1
                : (negPow!A > negPow!B ? negPow!A + 1 : negPow!B + 1),
            sumMaxBits!(posBits!A, posBits!B)
        );
    else static if (!isSigned!A && !isSigned!B)
        enum AddShape = Shape(
            0,
            sumMaxBits!(posBits!A, posBits!B)
        );
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

template SubShape(A, B)
{
    static if (isSigned!A && isSigned!B)
        enum SubShape = Shape(
            negPow!A >= posBits!B ? negPow!A + 1 : posBits!B + 1,
            posBits!A >= negPow!B ? posBits!A + 1 : negPow!B + 1
        );
    else static if (!isSigned!A && !isSigned!B)
        enum SubShape = Shape(
            posBits!B,
            posBits!A
        );
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

template MulShape(A, B)
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

template AddRep(A, B)
{
    alias AddRep = SelectRep!(AddShape!(A, B));
}

template SubRep(A, B)
{
    alias SubRep = SelectRep!(SubShape!(A, B));
}

template MulRep(A, B)
{
    alias MulRep = SelectRep!(MulShape!(A, B));
}

template QuotientRep(A, B)
{
    static assert(isIntegral!A && isIntegral!B);

    static if (!isSigned!B)
        alias QuotientRep = A;
    else static if (A.sizeof < long.sizeof)
    {
        static if (A.sizeof == 1) alias QuotientRep = short;
        else static if (A.sizeof == 2) alias QuotientRep = int;
        else alias QuotientRep = long;
    }
    else
        alias QuotientRep = void;
}

// ---------- Quantity layer ----------

struct Q(Spec, Rep)
{
    Rep value;

    auto opBinary(string op, OtherSpec, OtherRep)(Q!(OtherSpec, OtherRep) rhs) const
        @safe pure nothrow @nogc
        if (op == "+" &&
            !is(AddResult!(Spec, OtherSpec) == void) &&
            !is(AddRep!(Rep, OtherRep) == void))
    {
        alias RS = AddResult!(Spec, OtherSpec);
        alias RR = AddRep!(Rep, OtherRep);
        return Q!(RS, RR)(cast(RR)value + cast(RR)rhs.value);
    }

    auto opBinary(string op, OtherSpec, OtherRep)(Q!(OtherSpec, OtherRep) rhs) const
        @safe pure nothrow @nogc
        if (op == "-" &&
            !is(SubResult!(Spec, OtherSpec) == void) &&
            !is(SubRep!(Rep, OtherRep) == void))
    {
        alias RS = SubResult!(Spec, OtherSpec);
        alias RR = SubRep!(Rep, OtherRep);
        return Q!(RS, RR)(cast(RR)value - cast(RR)rhs.value);
    }

    auto opBinary(string op, S)(S scalar) const
        @safe pure nothrow @nogc
        if (op == "*" && isIntegral!S && isScalableValue!Spec &&
            !is(MulRep!(Rep, S) == void))
    {
        alias RR = MulRep!(Rep, S);
        return Q!(Spec, RR)(cast(RR)value * cast(RR)scalar);
    }

    auto opBinaryRight(string op, S)(S scalar) const
        @safe pure nothrow @nogc
        if (op == "*" && isIntegral!S && isScalableValue!Spec &&
            !is(MulRep!(S, Rep) == void))
    {
        alias RR = MulRep!(S, Rep);
        return Q!(Spec, RR)(cast(RR)scalar * cast(RR)value);
    }
}

enum DivisionStatus : ubyte
{
    exact,
    inexact,
    divisionByZero
}

struct DivResult(T)
{
private:
    T payload_;

public:
    bool hasValue;
    DivisionStatus status;

    static DivResult exact(T value) @safe pure nothrow @nogc
    {
        return DivResult(value, true, DivisionStatus.exact);
    }

    static DivResult failure(DivisionStatus status) @safe pure nothrow @nogc
    {
        return DivResult(T.init, false, status);
    }

    bool tryValue(out T value) const @safe pure nothrow @nogc
    {
        if (!hasValue)
            return false;
        value = payload_;
        return true;
    }
}

auto exactDiv(Spec, A, B)(Q!(Spec, A) q, B divisor)
    @safe pure nothrow @nogc
    if (isIntegral!A && isIntegral!B && isScalableValue!Spec &&
        !is(QuotientRep!(A, B) == void))
{
    alias R = QuotientRep!(A, B);
    alias QR = Q!(Spec, R);
    alias Result = DivResult!QR;

    if (divisor == 0)
        return Result.failure(DivisionStatus.divisionByZero);

    R a = cast(R)q.value;
    R b = cast(R)divisor;

    if (a % b != 0)
        return Result.failure(DivisionStatus.inexact);

    return Result.exact(QR(a / b));
}

// ---------- integrated gates ----------

@safe pure nothrow @nogc
long integratedCtfe()
{
    auto a = Q!(Length, int)(int.max);
    auto b = Q!(Length, uint)(uint.max);
    auto sum = a + b;
    static assert(is(typeof(sum) == Q!(Length, long)));

    auto d = Q!(Length, uint)(0) - Q!(Length, uint)(uint.max);
    static assert(is(typeof(d) == Q!(Length, long)));
    assert(d.value == -cast(long)uint.max);

    auto p = Q!(Length, uint)(uint.max) * uint.max;
    static assert(is(typeof(p) == Q!(Length, ulong)));
    assert(p.value == cast(ulong)uint.max * cast(ulong)uint.max);

    auto pr = uint.max * Q!(Length, uint)(uint.max);
    static assert(is(typeof(pr) == Q!(Length, ulong)));
    assert(pr.value == p.value);

    auto div = exactDiv(Q!(Length, int)(int.min), -1);
    Q!(Length, long) q;
    assert(div.tryValue(q));
    assert(q.value == -(cast(long)int.min));

    return sum.value;
}

enum ctfe = integratedCtfe();
static assert(ctfe == cast(long)int.max + cast(long)uint.max);

static assert(!__traits(compiles,
    Q!(Radius, int)(1) + Q!(Radius, int)(2)));
static assert(!__traits(compiles,
    Q!(Length, int)(1) + Q!(Radius, int)(2)));
static assert(!__traits(compiles,
    Q!(Length, long)(1) + Q!(Length, long)(2)));
static assert(!__traits(compiles,
    Q!(Length, ulong)(1) * Q!(Length, ulong)(2).value));
static assert(!__traits(compiles,
    exactDiv(Q!(Length, long)(5), long(2))));
static assert(!__traits(compiles,
    Q!(Length, int)(5) / int(2)));

void main()
{
    {
        auto r = exactDiv(Q!(Length, int)(5), 2);
        assert(r.status == DivisionStatus.inexact);
        assert(!r.hasValue);
    }
    {
        auto r = exactDiv(Q!(Length, int)(5), 0);
        assert(r.status == DivisionStatus.divisionByZero);
        assert(!r.hasValue);
    }
}
