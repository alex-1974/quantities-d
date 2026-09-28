module quantities.arithmetic;

import std.traits : isIntegral;

import quantities.arithmetic_rep : QuotientRep, ScaledMulRep;
import quantities.arithmetic_traits :
    ExternalProductResultSpec,
    ProductCanonicalRescale,
    ProductResultSpec,
    isScalableValue;
import quantities.quantity : Quantity;

/// Failure classification for exact Quantity product operations.
///
/// `inexact` means that the mathematical product cannot be represented
/// exactly in the selected result Spec's canonical integral unit.
enum ProductFailure : ubyte
{
    inexact
}

private struct ExactArithmeticResult(T, Failure)
    if (is(Failure == enum))
{
private:
    T payload_;
    Failure failure_ = Failure.init;
    bool hasValue_;

public:
    @property bool hasValue() const @safe pure nothrow @nogc
    {
        return hasValue_;
    }

    package(quantities) static ExactArithmeticResult exact(T value)
        @safe pure nothrow @nogc
    {
        ExactArithmeticResult result;
        result.payload_ = value;
        result.hasValue_ = true;
        return result;
    }

    package(quantities) static ExactArithmeticResult failed(Failure failure)
        @safe pure nothrow @nogc
    {
        ExactArithmeticResult result;
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

    bool tryFailure(out Failure failure) const
        @safe pure nothrow @nogc
    {
        if (hasValue_)
            return false;
        failure = failure_;
        return true;
    }
}

alias ProductResultValue(T) = ExactArithmeticResult!(T, ProductFailure);

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

private auto exactMulKernel(ResultSpec, LhsSpec, LhsRep, RhsSpec, RhsRep)(
    Quantity!(LhsSpec, LhsRep) lhs,
    Quantity!(RhsSpec, RhsRep) rhs)
    @safe pure nothrow @nogc
{
    alias Scale = ProductCanonicalRescale!(LhsSpec, RhsSpec, ResultSpec);
    alias ResultRep = ScaledMulRep!(
        LhsRep, RhsRep, cast(ulong)Scale.numerator);
    alias ResultQuantity = Quantity!(ResultSpec, ResultRep);
    alias Result = ProductResultValue!ResultQuantity;

    const ResultRep productValue =
        cast(ResultRep)lhs.canonicalValue *
        cast(ResultRep)rhs.canonicalValue;
    const ResultRep scaled =
        productValue * cast(ResultRep)Scale.numerator;
    const ResultRep denominator = cast(ResultRep)Scale.denominator;

    if (scaled % denominator != 0)
        return Result.failed(ProductFailure.inexact);

    return Result.exact(
        ResultQuantity.fromCanonical(scaled / denominator));
}

/// Multiplies two integral Quantities using operand-owned product semantics.
///
/// The result Spec is resolved through `ProductResultSpec`. This overload is
/// available only when the complete scaled product range fits a built-in
/// integral result Rep. Non-integral canonical rescaling returns an inexact
/// result rather than truncating. The operation is CTFE-capable and performs
/// no allocation.
auto exactMul(LhsSpec, LhsRep, RhsSpec, RhsRep)(
    Quantity!(LhsSpec, LhsRep) lhs,
    Quantity!(RhsSpec, RhsRep) rhs)
    @safe pure nothrow @nogc
    if (isIntegral!LhsRep &&
        isIntegral!RhsRep &&
        !is(ProductResultSpec!(LhsSpec, RhsSpec) == void) &&
        ProductCanonicalRescale!(
            LhsSpec,
            RhsSpec,
            ProductResultSpec!(LhsSpec, RhsSpec)).numerator > 0 &&
        !is(ScaledMulRep!(
            LhsRep,
            RhsRep,
            cast(ulong)ProductCanonicalRescale!(
                LhsSpec,
                RhsSpec,
                ProductResultSpec!(LhsSpec, RhsSpec)).numerator) == void) &&
        ProductCanonicalRescale!(
            LhsSpec,
            RhsSpec,
            ProductResultSpec!(LhsSpec, RhsSpec)).denominator <=
            ScaledMulRep!(
                LhsRep,
                RhsRep,
                cast(ulong)ProductCanonicalRescale!(
                    LhsSpec,
                    RhsSpec,
                    ProductResultSpec!(LhsSpec, RhsSpec)).numerator).max)
{
    alias ResultSpec = ProductResultSpec!(LhsSpec, RhsSpec);
    return exactMulKernel!ResultSpec(lhs, rhs);
}

/// Multiplies two integral Quantities using an explicit consumer relation set.
///
/// `Relations.Product!(LhsSpec, RhsSpec)` is authoritative. The operation is
/// exposed only when the complete operand ranges are representable and the
/// mathematical product unit already equals the result Spec's CanonicalUnit;
/// no canonical-unit truncation or runtime failure is possible.
auto product(alias Relations, LhsSpec, LhsRep, RhsSpec, RhsRep)(
    Quantity!(LhsSpec, LhsRep) lhs,
    Quantity!(RhsSpec, RhsRep) rhs)
    @safe pure nothrow @nogc
    if (isIntegral!LhsRep &&
        isIntegral!RhsRep &&
        !is(ExternalProductResultSpec!(
            Relations, LhsSpec, RhsSpec) == void) &&
        !is(ScaledMulRep!(LhsRep, RhsRep, 1) == void) &&
        ProductCanonicalRescale!(
            LhsSpec,
            RhsSpec,
            ExternalProductResultSpec!(
                Relations, LhsSpec, RhsSpec)).numerator == 1 &&
        ProductCanonicalRescale!(
            LhsSpec,
            RhsSpec,
            ExternalProductResultSpec!(
                Relations, LhsSpec, RhsSpec)).denominator == 1)
{
    alias ResultSpec =
        ExternalProductResultSpec!(Relations, LhsSpec, RhsSpec);
    alias ResultRep = ScaledMulRep!(LhsRep, RhsRep, 1);
    alias ResultQuantity = Quantity!(ResultSpec, ResultRep);

    return ResultQuantity.fromCanonical(
        cast(ResultRep)lhs.canonicalValue *
        cast(ResultRep)rhs.canonicalValue);
}

/// Multiplies two integral Quantities using an explicit consumer relation set.
///
/// Unlike the operand-owned overload, semantic resolution is exclusively
/// `ExternalProductResultSpec!(Relations, LhsSpec, RhsSpec)`. Exact canonical
/// rescaling is performed when the compile-time range proof admits it; a
/// value-dependent non-integral rescale reports `ProductFailure.inexact`.
auto exactMul(alias Relations, LhsSpec, LhsRep, RhsSpec, RhsRep)(
    Quantity!(LhsSpec, LhsRep) lhs,
    Quantity!(RhsSpec, RhsRep) rhs)
    @safe pure nothrow @nogc
    if (isIntegral!LhsRep &&
        isIntegral!RhsRep &&
        !is(ExternalProductResultSpec!(
            Relations, LhsSpec, RhsSpec) == void) &&
        ProductCanonicalRescale!(
            LhsSpec,
            RhsSpec,
            ExternalProductResultSpec!(
                Relations, LhsSpec, RhsSpec)).numerator > 0 &&
        !is(ScaledMulRep!(
            LhsRep,
            RhsRep,
            cast(ulong)ProductCanonicalRescale!(
                LhsSpec,
                RhsSpec,
                ExternalProductResultSpec!(
                    Relations, LhsSpec, RhsSpec)).numerator) == void) &&
        ProductCanonicalRescale!(
            LhsSpec,
            RhsSpec,
            ExternalProductResultSpec!(
                Relations, LhsSpec, RhsSpec)).denominator <=
            ScaledMulRep!(
                LhsRep,
                RhsRep,
                cast(ulong)ProductCanonicalRescale!(
                    LhsSpec,
                    RhsSpec,
                    ExternalProductResultSpec!(
                        Relations, LhsSpec, RhsSpec)).numerator).max)
{
    alias ResultSpec =
        ExternalProductResultSpec!(Relations, LhsSpec, RhsSpec);
    return exactMulKernel!ResultSpec(lhs, rhs);
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

        // A denominator must never be narrowed into ResultRep. Until exactMul
        // grows a wider/cross-cancelled denominator kernel, reject such a
        // specialization at compile time rather than corrupting the divisor.
        alias HugeDenominatorSquareUnit = DerivedUnit!(
            AreaDimension,
            ExactRatio!(1_000_000, 1));
        struct HugeDenominatorArea
        {
            alias Dimension = AreaDimension;
            alias CanonicalUnit = HugeDenominatorSquareUnit;
        }
        struct TinyProduct
        {
            alias Dimension = Length.Dimension;
            alias CanonicalUnit = Metre;

            template ProductWith(Rhs)
            {
                static if (is(Rhs == TinyProduct))
                    alias ProductWith = HugeDenominatorArea;
                else
                    alias ProductWith = void;
            }
        }
        static assert(!__traits(compiles,
            (cast(byte)1).quantity!(TinyProduct, Metre)
                .exactMul((cast(byte)1).quantity!(TinyProduct, Metre))));

        return true;
    }()));

    static assert(({
        import quantities.area : Area;
        import quantities.arithmetic_traits : ExternalProductResultSpec;
        import quantities.length : LengthDimension;

        struct ForeignLeft
        {
            alias Dimension = LengthDimension;
            alias CanonicalUnit = Metre;
        }

        struct ForeignRight
        {
            alias Dimension = LengthDimension;
            alias CanonicalUnit = Metre;
        }

        struct ConsumerRelations
        {
            template Product(Lhs, Rhs)
            {
                static if (is(Lhs == ForeignLeft) && is(Rhs == ForeignRight))
                    alias Product = Area;
                else
                    alias Product = void;
            }
        }

        static assert(is(ExternalProductResultSpec!(
            ConsumerRelations, ForeignLeft, ForeignRight) == Area));

        enum total =
            3.quantity!(ForeignLeft, Metre)
            .product!ConsumerRelations(4.quantity!(ForeignRight, Metre));
        static assert(is(typeof(total) == Quantity!(Area, long)));
        static assert(total.canonicalValue == 12);

        enum exact =
            3.quantity!(ForeignLeft, Metre)
            .exactMul!ConsumerRelations(4.quantity!(ForeignRight, Metre));
        static assert(exact.hasValue);
        static assert(({
            Quantity!(Area, long) area;
            return exact.tryValue(area) && area.canonicalValue == 12;
        }()));

        import quantities.area : AreaDimension;
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

        struct RescaledRelations
        {
            template Product(Lhs, Rhs)
            {
                static if (is(Lhs == ForeignLeft) && is(Rhs == ForeignRight))
                    alias Product = AreaKm2;
                else
                    alias Product = void;
            }
        }

        static assert(!__traits(compiles,
            1000.quantity!(ForeignLeft, Metre)
                .product!RescaledRelations(
                    1000.quantity!(ForeignRight, Metre))));

        enum rescaledExact =
            1000.quantity!(ForeignLeft, Metre)
            .exactMul!RescaledRelations(
                1000.quantity!(ForeignRight, Metre));
        static assert(rescaledExact.hasValue);
        static assert(({
            Quantity!(AreaKm2, long) area;
            return rescaledExact.tryValue(area)
                && area.canonicalValue == 1;
        }()));

        return true;
    }()));

    static assert(!__traits(compiles,
        long(5).quantity!(Length, Metre).exactDiv(long(2))));
}
