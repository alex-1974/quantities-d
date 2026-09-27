module negative;

struct ExactRatio(long N, long D)
{
    static assert(D != 0, "ExactRatio denominator must not be zero.");
    enum numerator = N;
    enum denominator = D;
}

struct LengthDimension {}
struct TimeDimension {}

struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1);
}

struct Second
{
    alias Dimension = TimeDimension;
    alias Scale = ExactRatio!(1, 1);
}

struct MissingUnitDimension
{
    alias Scale = ExactRatio!(1, 1);
}

struct MissingUnitScale
{
    alias Dimension = LengthDimension;
}

struct GoodSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct MissingSpecDimension
{
    alias CanonicalUnit = Metre;
}

struct MissingCanonicalUnit
{
    alias Dimension = LengthDimension;
}

struct WrongCanonicalDimension
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Second;
}

struct BadUnitDimensionSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = MissingUnitDimension;
}

struct BadUnitScaleSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = MissingUnitScale;
}

template isUnit(U)
{
    static if (!__traits(hasMember, U, "Dimension"))
        enum isUnit = false;
    else static if (!__traits(hasMember, U, "Scale"))
        enum isUnit = false;
    else static if (!__traits(hasMember, U.Scale, "numerator")
        || !__traits(hasMember, U.Scale, "denominator"))
        enum isUnit = false;
    else
        enum isUnit = U.Scale.denominator != 0;
}

template isQuantitySpec(S)
{
    static if (!__traits(hasMember, S, "Dimension"))
        enum isQuantitySpec = false;
    else static if (!__traits(hasMember, S, "CanonicalUnit"))
        enum isQuantitySpec = false;
    else static if (!isUnit!(S.CanonicalUnit))
        enum isQuantitySpec = false;
    else
        enum isQuantitySpec =
            is(S.Dimension == S.CanonicalUnit.Dimension);
}

struct Quantity(Spec, Rep)
{
    static assert(isQuantitySpec!Spec,
        "Quantity Spec must define Dimension and a valid CanonicalUnit with the same Dimension.");
    Rep value;
}

version (MissingSpecDimension)
    alias Bad = Quantity!(MissingSpecDimension, double);
version (MissingCanonicalUnit)
    alias Bad = Quantity!(MissingCanonicalUnit, double);
version (WrongCanonicalDimension)
    alias Bad = Quantity!(WrongCanonicalDimension, double);
version (MissingUnitDimension)
    alias Bad = Quantity!(BadUnitDimensionSpec, double);
version (MissingUnitScale)
    alias Bad = Quantity!(BadUnitScaleSpec, double);

void main() {}
