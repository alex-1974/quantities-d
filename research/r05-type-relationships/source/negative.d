module negative;

struct LengthDimension {}
struct TimeDimension {}

struct Ratio(long N, long D)
{
    enum num = N;
    enum den = D;
}

struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = Ratio!(1, 1);
}

struct Second
{
    alias Dimension = TimeDimension;
    alias Scale = Ratio!(1, 1);
}

struct GoodLengthSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct WrongUnitSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Second;
}

struct MissingUnitSpec
{
    alias Dimension = LengthDimension;
}

struct MissingDimensionSpec
{
    alias CanonicalUnit = Metre;
}

template validSpec(Spec)
{
    static if (__traits(hasMember, Spec, "Dimension")
        && __traits(hasMember, Spec, "CanonicalUnit"))
    {
        enum validSpec = is(Spec.Dimension == Spec.CanonicalUnit.Dimension);
    }
    else
        enum validSpec = false;
}

struct Quantity(Spec, Rep)
if (validSpec!Spec)
{
    Rep value;
}

static assert(validSpec!GoodLengthSpec);
static assert(!validSpec!WrongUnitSpec);
static assert(!validSpec!MissingUnitSpec);
static assert(!validSpec!MissingDimensionSpec);

version (NegativeWrongDimension)
{
    // Must fail: canonical Unit Dimension does not match Spec Dimension.
    alias Bad = Quantity!(WrongUnitSpec, double);
}

version (NegativeMissingCanonicalUnit)
{
    // Must fail: Spec does not define CanonicalUnit.
    alias Bad = Quantity!(MissingUnitSpec, double);
}

version (NegativeMissingDimension)
{
    // Must fail: Spec does not define Dimension.
    alias Bad = Quantity!(MissingDimensionSpec, double);
}

void main() {}
