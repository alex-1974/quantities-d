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

    alias X = production.ProductResult!(Radius, Radius);
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

    alias X = production.ProductResult!(Left, Right);
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

    alias X = production.ProductResult!(Left, Right);
}
