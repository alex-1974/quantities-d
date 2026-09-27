module negative;

struct ExactRatio(long N, long D)
{
    static assert(D != 0);
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

template isUnit(U)
{
    static if (!__traits(hasMember, U, "Dimension"))
        enum isUnit = false;
    else static if (!__traits(hasMember, U, "Scale"))
        enum isUnit = false;
    else
        enum isUnit = true;
}

template isSpec(S)
{
    static if (!__traits(hasMember, S, "Dimension"))
        enum isSpec = false;
    else static if (!__traits(hasMember, S, "CanonicalUnit"))
        enum isSpec = false;
    else static if (!isUnit!(S.CanonicalUnit))
        enum isSpec = false;
    else
        enum isSpec = is(S.Dimension == S.CanonicalUnit.Dimension);
}

struct Quantity(Spec, Rep)
{
private:
    Rep canonical_;
}

@safe pure nothrow @nogc
auto quantity(Spec, Unit, Rep)(Rep value)
{
    static assert(isSpec!Spec,
        "quantity: Spec must define Dimension and a valid CanonicalUnit.");
    static assert(isUnit!Unit,
        "quantity: Unit must define Dimension and Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "quantity: Spec and Unit must have the same Dimension.");

    return Quantity!(Spec, Rep)(value);
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

version (RawConstruction)
{
    // Research expectation: direct payload construction must not be a public
    // construction path once Quantity lives in its own module.
    auto x = Quantity!(Length, double)(1.0);
}
