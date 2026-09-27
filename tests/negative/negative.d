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
