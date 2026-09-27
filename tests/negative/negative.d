module negative;

import quantities;

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
