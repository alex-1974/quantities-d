module negative;

import quantities;
import production = quantities;

struct LengthDimension {}
struct TimeDimension {}

struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1);
}

struct Kilometre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1000, 1);
}

struct Second
{
    alias Dimension = TimeDimension;
    alias Scale = ExactRatio!(1, 1);
}

struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct BrokenSpec
{
    alias Dimension = LengthDimension;
}

struct BrokenUnit
{
    alias Dimension = LengthDimension;
}

version (WrongDimension)
{
    enum x = 1.0.quantity!(Length, Second);
}

version (BrokenSpecCase)
{
    enum x = 1.0.quantity!(BrokenSpec, Metre);
}

version (BrokenUnitCase)
{
    enum x = 1.0.quantity!(Length, BrokenUnit);
}

version (NonCanonicalConstruction)
{
    enum x = 1.0.quantity!(Length, Kilometre);
}

version (NonCanonicalExtraction)
{
    enum q = 1000.0.quantity!(Length, Metre);
    enum x = q.inUnit!Kilometre;
}


version (CheckedWrongDimension)
{
    enum x = 1L.checkedQuantity!(Length, Second);
}

version (CheckedBrokenSpec)
{
    enum x = 1L.checkedQuantity!(BrokenSpec, Metre);
}

version (CheckedBrokenUnit)
{
    enum x = 1L.checkedQuantity!(Length, BrokenUnit);
}

version (CheckedExtractionWrongDimension)
{
    enum q = 1L.quantity!(Length, Metre);
    enum x = q.checkedIn!Second;
}


version (M2NonCanonicalKilometreConstruction)
{
    enum x = 1L.quantity!(production.Length, production.Kilometre);
}

version (M2NonCanonicalInternationalFootExtraction)
{
    enum q = 381L.quantity!(production.Length, production.Metre);
    enum x = q.inUnit!(production.InternationalFoot);
}

version (M2WrongDimensionConstruction)
{
    enum x = 1L.checkedQuantity!(production.Length, Second);
}


version (M3NonAdditiveSameSpecAddition)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    enum x = 1.quantity!(Radius, production.Metre)
        + 2.quantity!(Radius, production.Metre);
}

version (M3CrossSpecAddition)
{
    struct OtherLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
        enum closedAdditiveValue = true;
    }

    enum x = 1.quantity!(production.Length, production.Metre)
        + 2.quantity!(OtherLength, production.Metre);
}

version (M3ClassOAddition)
{
    enum x = long.max.quantity!(production.Length, production.Metre)
        + long.max.quantity!(production.Length, production.Metre);
}

version (M3CheckedAddMixed64ClassOM)
{
    enum x =
        long(1).quantity!(production.Length, production.Metre)
        .checkedAdd(
            ulong(1).quantity!(production.Length, production.Metre));
}

version (M3CheckedAddInvalidSemantics)
{
    struct OtherLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
        enum closedAdditiveValue = true;
    }

    enum x =
        long(1).quantity!(production.Length, production.Metre)
        .checkedAdd(
            long(1).quantity!(OtherLength, production.Metre));
}


version (M3CheckedSubMixed64ClassOM)
{
    enum x =
        long(1).quantity!(production.Length, production.Metre)
        .checkedSub(
            ulong(1).quantity!(production.Length, production.Metre));
}

version (M3CheckedSubInvalidSemantics)
{
    struct OtherLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
        enum closedAdditiveValue = true;
    }

    enum x =
        long(1).quantity!(production.Length, production.Metre)
        .checkedSub(
            long(1).quantity!(OtherLength, production.Metre));
}


version (M3RawIntegralDivision)
{
    enum x = 5.quantity!(production.Length, production.Metre) / 2;
}


version (M3NonScalableMultiplication)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    enum x = 2.quantity!(Radius, production.Metre) * 3;
}

version (M3NonScalableRightMultiplication)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    enum x = 3 * 2.quantity!(Radius, production.Metre);
}

version (M3ClassOMultiplication)
{
    enum x = ulong.max.quantity!(production.Length, production.Metre)
        * ulong.max;
}

version (M3UnsafeIntFloatScalarMultiplication)
{
    enum x =
        1.quantity!(production.Length, production.Metre)
        * 0.5f;
}

version (M3UnsafeLongDoubleScalarMultiplication)
{
    enum x =
        long.max.quantity!(production.Length, production.Metre)
        * 0.5;
}

version (M3UnsafeRightLongDoubleScalarMultiplication)
{
    enum x =
        0.5
        * long.max.quantity!(production.Length, production.Metre);
}


version (R0416RawIntegralScalarDivision)
{
    enum x =
        6.quantity!(production.Length, production.Metre) / 3;
}

version (R0416UnsafeIntFloatScalarDivision)
{
    enum x =
        1.quantity!(production.Length, production.Metre) / 0.5f;
}

version (R0416UnsafeLongDoubleScalarDivision)
{
    enum x =
        long.max.quantity!(production.Length, production.Metre) / 0.5;
}

version (R0416ScalarOverQuantity)
{
    enum x =
        2.0 / 3.0.quantity!(production.Length, production.Metre);
}

version (R0416NonScalableScalarDivision)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    enum x =
        6.0.quantity!(Radius, production.Metre) / 3.0;
}

version (ConversionUnsupportedUlongSource)
{
    enum x =
        ulong.max.checkedQuantity!(
            production.Length,
            production.Metre);
}

version (ConversionUnsupportedFloatSource)
{
    enum x =
        1.0f.checkedQuantity!(
            production.Length,
            production.Metre);
}

version (ConversionUnsupportedRealSource)
{
    enum x =
        1.0L.checkedQuantity!(
            production.Length,
            production.Metre);
}

version (ConversionUnsupportedIntExactSource)
{
    enum x =
        1.exactQuantity!(
            production.Length,
            production.Metre);
}

version (ConversionUnsupportedDoubleRoundedSource)
{
    enum x =
        1.0.roundedQuantity!(
            production.Length,
            production.Metre,
            production.RoundingMode.towardZero);
}

version (M3NonScalableExactDivision)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    enum x = 6.quantity!(Radius, production.Metre).exactDiv(3);
}

version (M3ClassOExactDivision)
{
    enum x = long(6).quantity!(production.Length, production.Metre)
        .exactDiv(long(3));
}


version (M3ProductMissingRelation)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    alias X = production.ProductResultSpec!(Radius, Radius);
    static assert(!is(X == void), "probe must fail: missing product relation");
}

version (M3ProductConflictingRelations)
{
    struct Left
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template ProductWith(Rhs)
        {
            alias ProductWith = production.Area;
        }
    }

    struct OtherArea
    {
        alias Dimension = production.AreaDimension;
        alias CanonicalUnit = production.SquareMetre;
    }

    struct Right
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template ProductFromLeft(Lhs)
        {
            alias ProductFromLeft = OtherArea;
        }
    }

    alias X = production.ProductResultSpec!(Left, Right);
}

version (M3ProductWrongResultDimension)
{
    struct WrongResult
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct Left
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template ProductWith(Rhs)
        {
            alias ProductWith = WrongResult;
        }
    }

    struct Right
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    alias X = production.ProductResultSpec!(Left, Right);
}


version (M3QuantityProductMissingRelation)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    enum x =
        2.quantity!(Radius, production.Metre)
        * 3.quantity!(Radius, production.Metre);
}

version (M3QuantityProductClassO)
{
    enum x =
        long.max.quantity!(production.Length, production.Metre)
        * long.max.quantity!(production.Length, production.Metre);
}

version (M3UnsafeIntFloatQuantityProduct)
{
    enum x =
        1.quantity!(production.Length, production.Metre)
        * 0.5f.quantity!(production.Length, production.Metre);
}

version (M3UnsafeLongDoubleQuantityProduct)
{
    enum x =
        long.max.quantity!(production.Length, production.Metre)
        * 0.5.quantity!(production.Length, production.Metre);
}

version (M3QuantityProductCanonicalRescale)
{
    alias SquareKilometre = production.DerivedUnit!(
        production.AreaDimension,
        production.ExactRatio!(1_000_000, 1));

    struct AreaKm2
    {
        alias Dimension = production.AreaDimension;
        alias CanonicalUnit = SquareKilometre;
    }

    struct LengthToKm2
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template ProductWith(Rhs)
        {
            alias ProductWith = AreaKm2;
        }
    }

    enum x =
        1000.quantity!(LengthToKm2, production.Metre)
        * 1000.quantity!(LengthToKm2, production.Metre);
}

version (M3FloatingQuantityProductCanonicalRescale)
{
    alias ScaledSquareMetre = production.DerivedUnit!(
        production.AreaDimension,
        production.ExactRatio!(2, 1));

    struct ScaledArea
    {
        alias Dimension = production.AreaDimension;
        alias CanonicalUnit = ScaledSquareMetre;
    }

    struct LengthToScaledArea
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template ProductWith(Rhs)
        {
            alias ProductWith = ScaledArea;
        }
    }

    enum x =
        1.5.quantity!(LengthToScaledArea, production.Metre)
        * 2.0.quantity!(LengthToScaledArea, production.Metre);
}


version (R0417FloatingQuantityProductCanonicalRescale)
{
    alias ScaledSquareMetre = production.DerivedUnit!(
        production.AreaDimension,
        production.ExactRatio!(2, 1));

    struct ScaledArea
    {
        alias Dimension = production.AreaDimension;
        alias CanonicalUnit = ScaledSquareMetre;
    }

    struct LengthToScaledArea
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template ProductWith(Rhs)
        {
            alias ProductWith = ScaledArea;
        }
    }

    enum x =
        1.5f.quantity!(LengthToScaledArea, production.Metre)
        * 2.0f.quantity!(LengthToScaledArea, production.Metre);
}


version (R0417RealQuantityProductCanonicalRescale)
{
    alias ScaledSquareMetre = production.DerivedUnit!(
        production.AreaDimension,
        production.ExactRatio!(2, 1));

    struct ScaledArea
    {
        alias Dimension = production.AreaDimension;
        alias CanonicalUnit = ScaledSquareMetre;
    }

    struct LengthToScaledArea
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template ProductWith(Rhs)
        {
            alias ProductWith = ScaledArea;
        }
    }

    enum x =
        1.5L.quantity!(LengthToScaledArea, production.Metre)
        * 2.0L.quantity!(LengthToScaledArea, production.Metre);
}


version (M3ExternalProductMissingRelation)
{
    struct ForeignLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct EmptyRelations
    {
        template Product(Lhs, Rhs)
        {
            alias Product = void;
        }
    }

    enum x =
        2.quantity!(ForeignLength, production.Metre)
        .product!EmptyRelations(
            3.quantity!(ForeignLength, production.Metre));
}

version (M3ExternalProductWrongResultDimension)
{
    struct ForeignLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct WrongResult
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct Relations
    {
        template Product(Lhs, Rhs)
        {
            alias Product = WrongResult;
        }
    }

    alias X = production.ExternalProductResultSpec!(
        Relations, ForeignLength, ForeignLength);
}

version (M3ExternalProductClassO)
{
    struct ForeignLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct Relations
    {
        template Product(Lhs, Rhs)
        {
            alias Product = production.Area;
        }
    }

    enum x =
        long.max.quantity!(ForeignLength, production.Metre)
        .product!Relations(
            long.max.quantity!(ForeignLength, production.Metre));
}

version (M3ExternalProductCanonicalRescale)
{
    alias SquareKilometre = production.DerivedUnit!(
        production.AreaDimension,
        production.ExactRatio!(1_000_000, 1));

    struct ForeignLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct AreaKm2
    {
        alias Dimension = production.AreaDimension;
        alias CanonicalUnit = SquareKilometre;
    }

    struct Relations
    {
        template Product(Lhs, Rhs)
        {
            alias Product = AreaKm2;
        }
    }

    enum x =
        1000.quantity!(ForeignLength, production.Metre)
        .product!Relations(
            1000.quantity!(ForeignLength, production.Metre));
}


version (M3CheckedMulMissingRelation)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    enum x =
        long(2).quantity!(Radius, production.Metre)
        .checkedMul(long(3).quantity!(Radius, production.Metre));
}

version (M3CheckedMulMixed64ClassOM)
{
    enum x =
        long(2).quantity!(production.Length, production.Metre)
        .checkedMul(
            ulong(3).quantity!(production.Length, production.Metre));
}

version (M3ExternalCheckedMulMissingRelation)
{
    struct ForeignLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct EmptyRelations
    {
        template Product(Lhs, Rhs)
        {
            alias Product = void;
        }
    }

    enum x =
        long(2).quantity!(ForeignLength, production.Metre)
        .checkedMul!EmptyRelations(
            long(3).quantity!(ForeignLength, production.Metre));
}


version (M3QuotientMissingRelation)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    alias X = production.QuotientResultSpec!(Radius, Radius);
    static assert(!is(X == void), "probe must fail: missing quotient relation");
}

version (M3QuotientConflictingRelations)
{
    alias Unitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(1, 1));

    struct RatioA
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = Unitless;
    }

    struct RatioB
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = Unitless;
    }

    struct Left
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioA;
        }
    }

    struct Right
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientFromLeft(Lhs)
        {
            alias QuotientFromLeft = RatioB;
        }
    }

    alias X = production.QuotientResultSpec!(Left, Right);
}

version (M3QuotientWrongResultDimension)
{
    struct WrongResult
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct Left
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = WrongResult;
        }
    }

    struct Right
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    alias X = production.QuotientResultSpec!(Left, Right);
}

version (M3QuantityQuotientMissingRelation)
{
    struct Radius
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    enum x =
        6.quantity!(Radius, production.Metre)
        .exactDiv(3.quantity!(Radius, production.Metre));
}

version (M3QuantityQuotientClassO)
{
    alias Unitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(1, 1));

    struct RatioSpec
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = Unitless;
    }

    struct LengthRatio
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    enum x =
        long(6).quantity!(LengthRatio, production.Metre)
        .exactDiv(long(3).quantity!(LengthRatio, production.Metre));
}

version (M3QuantityRawIntegralQuotient)
{
    alias Unitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(1, 1));

    struct RatioSpec
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = Unitless;
    }

    struct LengthRatio
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    enum x =
        6.quantity!(LengthRatio, production.Metre)
        / 3.quantity!(LengthRatio, production.Metre);
}

version (M3UnsafeIntFloatQuantityQuotient)
{
    alias Unitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(1, 1));

    struct RatioSpec
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = Unitless;
    }

    struct LengthRatio
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    enum x =
        1.quantity!(LengthRatio, production.Metre)
        / 0.5f.quantity!(LengthRatio, production.Metre);
}

version (M3UnsafeLongDoubleQuantityQuotient)
{
    alias Unitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(1, 1));

    struct RatioSpec
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = Unitless;
    }

    struct LengthRatio
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    enum x =
        long.max.quantity!(LengthRatio, production.Metre)
        / 0.5.quantity!(LengthRatio, production.Metre);
}

version (M3FloatingQuantityQuotientCanonicalRescale)
{
    alias ScaledUnitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(2, 1));

    struct RatioSpec
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = ScaledUnitless;
    }

    struct LengthRatio
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    enum x =
        6.0.quantity!(LengthRatio, production.Metre)
        / 3.0.quantity!(LengthRatio, production.Metre);
}

version (R0417FloatingQuantityQuotientCanonicalRescale)
{
    alias ScaledUnitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(2, 1));

    struct RatioSpec
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = ScaledUnitless;
    }

    struct LengthRatio
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    enum x =
        6.0f.quantity!(LengthRatio, production.Metre)
        / 3.0f.quantity!(LengthRatio, production.Metre);
}

version (R0417RealQuantityQuotientCanonicalRescale)
{
    alias ScaledUnitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(2, 1));

    struct RatioSpec
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = ScaledUnitless;
    }

    struct LengthRatio
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    enum x =
        6.0L.quantity!(LengthRatio, production.Metre)
        / 3.0L.quantity!(LengthRatio, production.Metre);
}

version (M3ExternalQuotientMissingRelation)
{
    struct ForeignLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct EmptyRelations
    {
        template Quotient(Lhs, Rhs)
        {
            alias Quotient = void;
        }
    }

    enum x =
        6.quantity!(ForeignLength, production.Metre)
        .exactDiv!EmptyRelations(
            3.quantity!(ForeignLength, production.Metre));
}

version (M3ExternalQuotientWrongResultDimension)
{
    struct ForeignLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct WrongResult
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;
    }

    struct Relations
    {
        template Quotient(Lhs, Rhs)
        {
            alias Quotient = WrongResult;
        }
    }

    alias X = production.ExternalQuotientResultSpec!(
        Relations, ForeignLength, ForeignLength);
}

version (M3ExternalQuotientNoFallback)
{
    alias Unitless = production.DerivedUnit!(
        production.Dimensionless,
        production.ExactRatio!(1, 1));

    struct RatioSpec
    {
        alias Dimension = production.Dimensionless;
        alias CanonicalUnit = Unitless;
    }

    struct IntrinsicLength
    {
        alias Dimension = production.LengthDimension;
        alias CanonicalUnit = production.Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    struct EmptyRelations
    {
        template Quotient(Lhs, Rhs)
        {
            alias Quotient = void;
        }
    }

    enum x =
        6.quantity!(IntrinsicLength, production.Metre)
        .exactDiv!EmptyRelations(
            3.quantity!(IntrinsicLength, production.Metre));
}
