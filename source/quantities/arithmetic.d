module quantities.arithmetic;

import std.traits : isIntegral;

import quantities.arithmetic_rep : QuotientRep;
import quantities.arithmetic_traits : isScalableValue;
import quantities.quantity : Quantity;

enum DivisionStatus : ubyte
{
    exact,
    inexact,
    divisionByZero
}

struct DivisionResult(T)
{
private:
    T payload_;
    bool hasValue_;
    DivisionStatus status_ = DivisionStatus.inexact;

public:
    @property bool hasValue() const @safe pure nothrow @nogc
    {
        return hasValue_;
    }

    @property DivisionStatus status() const @safe pure nothrow @nogc
    {
        return status_;
    }

    package(quantities) static DivisionResult exact(T value)
        @safe pure nothrow @nogc
    {
        DivisionResult result;
        result.payload_ = value;
        result.hasValue_ = true;
        result.status_ = DivisionStatus.exact;
        return result;
    }

    package(quantities) static DivisionResult failure(DivisionStatus status)
        @safe pure nothrow @nogc
    {
        DivisionResult result;
        result.status_ = status;
        return result;
    }

    bool tryValue(out T value) const @safe pure nothrow @nogc
    {
        if (!hasValue_)
            return false;

        value = payload_;
        return true;
    }
}

auto exactDiv(Spec, Rep, Scalar)(
    Quantity!(Spec, Rep) quantity,
    Scalar divisor)
    @safe pure nothrow @nogc
    if (isIntegral!Rep &&
        isIntegral!Scalar &&
        isScalableValue!Spec &&
        !is(QuotientRep!(Rep, Scalar) == void))
{
    alias ResultRep = QuotientRep!(Rep, Scalar);
    alias ResultQuantity = Quantity!(Spec, ResultRep);
    alias Result = DivisionResult!ResultQuantity;

    if (divisor == 0)
        return Result.failure(DivisionStatus.divisionByZero);

    const ResultRep lhs = cast(ResultRep)quantity.canonicalValue;
    const ResultRep rhs = cast(ResultRep)divisor;

    if (lhs % rhs != 0)
        return Result.failure(DivisionStatus.inexact);

    return Result.exact(
        ResultQuantity.fromCanonical(lhs / rhs));
}

@safe unittest
{
    import quantities.length : Length, Metre;
    import quantities.quantity : quantity;

    enum defaultResult = DivisionResult!(Quantity!(Length, int)).init;
    static assert(defaultResult.status == DivisionStatus.inexact);
    static assert(!defaultResult.hasValue);

    enum exact = 6.quantity!(Length, Metre).exactDiv(3);
    static assert(exact.status == DivisionStatus.exact);
    static assert(exact.hasValue);
    static assert(({
        Quantity!(Length, long) value;
        return exact.tryValue(value)
            && value.canonicalValue == 2;
    }()));

    enum widened = int.min.quantity!(Length, Metre).exactDiv(-1);
    static assert(widened.status == DivisionStatus.exact);
    static assert(({
        Quantity!(Length, long) value;
        return widened.tryValue(value)
            && value.canonicalValue == -(cast(long)int.min);
    }()));

    enum inexact = 5.quantity!(Length, Metre).exactDiv(2);
    static assert(inexact.status == DivisionStatus.inexact);
    static assert(!inexact.hasValue);

    enum zero = 5.quantity!(Length, Metre).exactDiv(0);
    static assert(zero.status == DivisionStatus.divisionByZero);
    static assert(!zero.hasValue);

    static assert(!__traits(compiles,
        long(5).quantity!(Length, Metre).exactDiv(long(2))));
}
