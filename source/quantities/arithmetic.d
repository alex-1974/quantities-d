module quantities.arithmetic;

import std.traits : isIntegral;

import quantities.arithmetic_rep : QuotientRep, ScaledMulRep;
import quantities.arithmetic_traits :
    ProductCanonicalRescale,
    ProductResult,
    isScalableValue;
import quantities.quantity : Quantity;

enum ProductFailure : ubyte
{
    inexact,
    overflow
}

struct ProductResultValue(T)
{
private:
    T payload_;
    ProductFailure failure_ = ProductFailure.inexact;
    bool hasValue_;

public:
    @property bool hasValue() const @safe pure nothrow @nogc
    {
        return hasValue_;
    }

    package(quantities) static ProductResultValue exact(T value)
        @safe pure nothrow @nogc
    {
        ProductResultValue result;
        result.payload_ = value;
        result.hasValue_ = true;
        return result;
    }

    package(quantities) static ProductResultValue failed(ProductFailure failure)
        @safe pure nothrow @nogc
    {
        ProductResultValue result;
        result.failure_ = failure;
        return result;
    }

    bool tryValue(out T value) const @safe pure nothrow @nogc
    {
        if (!hasValue_)
            return false;
        value = payload_;
        return true;
    }

    bool tryFailure(out ProductFailure failure) const
        @safe pure nothrow @nogc
    {
        if (hasValue_)
            return false;
        failure = failure_;
        return true;
    }
}

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

    package(quantities) static DivisionResult inexact()
        @safe pure nothrow @nogc
    {
        DivisionResult result;
        result.status_ = DivisionStatus.inexact;
        return result;
    }

    package(quantities) static DivisionResult divisionByZero()
        @safe pure nothrow @nogc
    {
        DivisionResult result;
        result.status_ = DivisionStatus.divisionByZero;
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

auto exactMul(LhsSpec, LhsRep, RhsSpec, RhsRep)(
    Quantity!(LhsSpec, LhsRep) lhs,
    Quantity!(RhsSpec, RhsRep) rhs)
    @safe pure nothrow @nogc
    if (isIntegral!LhsRep &&
        isIntegral!RhsRep &&
        !is(ProductResult!(LhsSpec, RhsSpec) == void) &&
        ProductCanonicalRescale!(
            LhsSpec,
            RhsSpec,
            ProductResult!(LhsSpec, RhsSpec)).numerator > 0 &&
        !is(ScaledMulRep!(
            LhsRep,
            RhsRep,
            cast(ulong)ProductCanonicalRescale!(
                LhsSpec,
                RhsSpec,
                ProductResult!(LhsSpec, RhsSpec)).numerator) == void))
{
    alias ResultSpec = ProductResult!(LhsSpec, RhsSpec);
    alias Scale = ProductCanonicalRescale!(LhsSpec, RhsSpec, ResultSpec);
    alias ResultRep = ScaledMulRep!(
        LhsRep, RhsRep, cast(ulong)Scale.numerator);
    alias ResultQuantity = Quantity!(ResultSpec, ResultRep);
    alias Result = ProductResultValue!ResultQuantity;

    const ResultRep product =
        cast(ResultRep)lhs.canonicalValue *
        cast(ResultRep)rhs.canonicalValue;
    const ResultRep scaled =
        product * cast(ResultRep)Scale.numerator;
    const ResultRep denominator = cast(ResultRep)Scale.denominator;

    if (scaled % denominator != 0)
        return Result.failed(ProductFailure.inexact);

    return Result.exact(
        ResultQuantity.fromCanonical(scaled / denominator));
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
        return Result.divisionByZero();

    const ResultRep lhs = cast(ResultRep)quantity.canonicalValue;
    const ResultRep rhs = cast(ResultRep)divisor;

    if (lhs % rhs != 0)
        return Result.inexact();

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

    static assert(({
        import quantities.area : Area, AreaDimension;
        import quantities.ratio : ExactRatio;
        import quantities.unit : DerivedUnit;

        alias SquareKilometre = DerivedUnit!(
            AreaDimension,
            ExactRatio!(1_000_000, 1));

        struct AreaKm2
        {
            alias Dimension = AreaDimension;
            alias CanonicalUnit = SquareKilometre;
        }

        struct LengthKm2Product
        {
            alias Dimension = Length.Dimension;
            alias CanonicalUnit = Metre;

            template ProductWith(Rhs)
            {
                static if (is(Rhs == LengthKm2Product))
                    alias ProductWith = AreaKm2;
                else
                    alias ProductWith = void;
            }
        }

        enum inexactProduct =
            3.quantity!(LengthKm2Product, Metre)
            .exactMul(4.quantity!(LengthKm2Product, Metre));
        static assert(!inexactProduct.hasValue);
        static assert(({
            ProductFailure failure;
            return inexactProduct.tryFailure(failure)
                && failure == ProductFailure.inexact;
        }()));

        enum exactProduct =
            1000.quantity!(LengthKm2Product, Metre)
            .exactMul(1000.quantity!(LengthKm2Product, Metre));
        static assert(exactProduct.hasValue);
        static assert(({
            Quantity!(AreaKm2, long) area;
            return exactProduct.tryValue(area)
                && area.canonicalValue == 1;
        }()));

        // Opposite rescale direction: the mathematical product unit is km²
        // while canonical storage is m², so the exact rescale numerator is
        // 1_000_000. ScaledMulRep must widen before multiplication.
        import quantities.length : Kilometre;

        struct KilometreLengthProduct
        {
            alias Dimension = Length.Dimension;
            alias CanonicalUnit = Kilometre;

            template ProductWith(Rhs)
            {
                static if (is(Rhs == KilometreLengthProduct))
                    alias ProductWith = Area;
                else
                    alias ProductWith = void;
            }
        }

        enum scaledUp =
            (cast(byte)1).quantity!(KilometreLengthProduct, Kilometre)
            .exactMul((cast(byte)1).quantity!(KilometreLengthProduct, Kilometre));
        static assert(scaledUp.hasValue);
        static assert(({
            Quantity!(Area, long) area;
            return scaledUp.tryValue(area)
                && area.canonicalValue == 1_000_000;
        }()));

        return true;
    }()));

    static assert(!__traits(compiles,
        long(5).quantity!(Length, Metre).exactDiv(long(2))));
}
