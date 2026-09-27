module r13_core;

struct ExactRatio(long N, long D)
{
    static assert(D != 0);
    enum numerator = N;
    enum denominator = D;
}

struct LengthDimension {}

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

struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
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

    @safe pure nothrow @nogc
    this(Rep canonical)
    {
        canonical_ = canonical;
    }

    // Module-private trusted construction path. The public quantity()
    // function below is in this same module and can call it; importing
    // consumers cannot.
    @safe pure nothrow @nogc
    private static Quantity fromCanonical(Rep canonical)
    {
        return Quantity(canonical);
    }

public:
    @safe pure nothrow @nogc
    Rep canonicalValue() const
    {
        return canonical_;
    }
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

    const scaled = cast(Rep)(
        value * cast(Rep) Unit.Scale.numerator
        / cast(Rep) Unit.Scale.denominator);

    return Quantity!(Spec, Rep).fromCanonical(scaled);
}
