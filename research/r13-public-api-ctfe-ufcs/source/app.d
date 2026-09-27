module app;

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

struct Radius
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct Quantity(Spec, Rep)
{
private:
    Rep canonical_;

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
    static assert(is(Spec.Dimension == Unit.Dimension));
    static assert(is(Spec.Dimension == Spec.CanonicalUnit.Dimension));

    alias ResultRep = Rep;
    const scaled = cast(ResultRep)(
        value * cast(ResultRep) Unit.Scale.numerator
        / cast(ResultRep) Unit.Scale.denominator);

    return Quantity!(Spec, ResultRep)(scaled);
}

@safe pure nothrow @nogc
auto inUnit(Unit, Spec, Rep)(Quantity!(Spec, Rep) q)
{
    static assert(is(Unit.Dimension == Spec.Dimension));

    return q.canonicalValue
        * cast(Rep) Unit.Scale.denominator
        / cast(Rep) Unit.Scale.numerator;
}

@safe pure nothrow @nogc
auto convertSpec(TargetSpec, SourceSpec, Rep)(Quantity!(SourceSpec, Rep) q)
{
    static assert(is(TargetSpec.Dimension == SourceSpec.Dimension));
    static assert(is(TargetSpec.CanonicalUnit == SourceSpec.CanonicalUnit));

    return Quantity!(TargetSpec, Rep)(q.canonicalValue);
}

void main()
{
    // Free-function construction.
    auto a = quantity!(Length, Metre)(12.5);
    assert(a.canonicalValue == 12.5);

    // Same function through UFCS.
    auto b = 12.5.quantity!(Length, Metre);
    assert(b.canonicalValue == 12.5);

    // CTFE + UFCS.
    enum km = 1.0.quantity!(Length, Kilometre);
    static assert(km.canonicalValue == 1000.0);

    enum metres = km.inUnit!Metre;
    static assert(metres == 1000.0);

    enum kilometres = km.inUnit!Kilometre;
    static assert(kilometres == 1.0);

    // Spec is explicit even though Unit is shared.
    enum radius = 6_378.137.quantity!(Radius, Kilometre);
    static assert(radius.canonicalValue == 6_378_137.0);

    // Explicit semantic conversion between same-dimension Specs is possible
    // mechanically, but whether it should be public is a separate policy.
    enum asLength = radius.convertSpec!Length;
    static assert(asLength.canonicalValue == radius.canonicalValue);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
}
