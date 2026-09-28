module app;

import std.traits : isIntegral, isSigned;

enum DivisionStatus : ubyte
{
    exact,
    inexact,
    overflow,
    divisionByZero
}

struct Q(Spec, Rep)
{
    Rep value;
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

auto exactDiv(Spec, A, B)(Q!(Spec, A) q, B divisor)
    @safe pure nothrow @nogc
    if (isIntegral!A && isIntegral!B && !is(QuotientRep!(A, B) == void))
{
    alias R = QuotientRep!(A, B);
    alias QR = Q!(Spec, R);
    alias Result = DivResult!QR;

    if (divisor == 0)
        return Result.failure(DivisionStatus.divisionByZero);

    // Convert to the statically proven result representation before %, /.
    // This also avoids the source-Rep T.min / -1 trap.
    R a = cast(R)q.value;
    R b = cast(R)divisor;

    if (a % b != 0)
        return Result.failure(DivisionStatus.inexact);

    return Result.exact(QR(a / b));
}

struct Length {}

@safe pure nothrow @nogc
long attributeProbe()
{
    auto r = exactDiv(Q!(Length, int)(int.min), -1);
    Q!(Length, long) q;
    assert(r.tryValue(q));
    return q.value;
}

enum ctfe = attributeProbe();
static assert(ctfe == -(cast(long)int.min));

static assert(__traits(compiles,
    exactDiv(Q!(Length, int)(5), int(2))));
static assert(!__traits(compiles,
    exactDiv(Q!(Length, long)(5), long(2))));
static assert(!__traits(compiles,
    Q!(Length, int)(5) / int(2)));

void main()
{
    {
        auto r = exactDiv(Q!(Length, int)(6), int(3));
        assert(r.status == DivisionStatus.exact);
        Q!(Length, long) q;
        assert(r.tryValue(q));
        assert(q.value == 2);
    }
    {
        auto r = exactDiv(Q!(Length, int)(5), int(2));
        assert(r.status == DivisionStatus.inexact);
        assert(!r.hasValue);
    }
    {
        auto r = exactDiv(Q!(Length, int)(5), int(0));
        assert(r.status == DivisionStatus.divisionByZero);
        assert(!r.hasValue);
    }
    {
        auto r = exactDiv(Q!(Length, int)(int.min), int(-1));
        assert(r.status == DivisionStatus.exact);
        Q!(Length, long) q;
        assert(r.tryValue(q));
        assert(q.value == -(cast(long)int.min));
    }
    {
        auto r = exactDiv(Q!(Length, uint)(5), int(-1));
        assert(r.status == DivisionStatus.exact);
        Q!(Length, long) q;
        assert(r.tryValue(q));
        assert(q.value == -5);
    }
    {
        auto r = exactDiv(Q!(Length, int)(-5), uint(2));
        assert(r.status == DivisionStatus.inexact);
        assert(!r.hasValue);
    }
}
