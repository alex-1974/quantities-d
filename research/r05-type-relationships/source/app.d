module app;

struct LengthDimension {}

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

struct Kilometre
{
    alias Dimension = LengthDimension;
    alias Scale = Ratio!(1000, 1);
}

struct InternationalFoot
{
    alias Dimension = LengthDimension;
    alias Scale = Ratio!(381, 1250);
}

struct USSurveyFoot
{
    alias Dimension = LengthDimension;
    alias Scale = Ratio!(1200, 3937);
}

struct LengthSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct RadiusSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct HeightSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct LinearResolutionSpec
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

template validSpec(Spec)
{
    enum validSpec =
        __traits(hasMember, Spec, "Dimension")
        && __traits(hasMember, Spec, "CanonicalUnit")
        && is(Spec.Dimension == Spec.CanonicalUnit.Dimension);
}

struct Quantity(Spec, Rep)
if (validSpec!Spec)
{
    Rep value;
}

@safe pure nothrow @nogc
Quantity!(Spec, Rep) fromCanonical(Spec, Rep)(Rep value)
if (validSpec!Spec)
{
    return Quantity!(Spec, Rep)(value);
}

void main()
{
    static assert(validSpec!LengthSpec);
    static assert(validSpec!RadiusSpec);
    static assert(validSpec!HeightSpec);
    static assert(validSpec!LinearResolutionSpec);

    static assert(is(LengthSpec.Dimension == RadiusSpec.Dimension));
    static assert(is(LengthSpec.CanonicalUnit == RadiusSpec.CanonicalUnit));
    static assert(!is(Quantity!(LengthSpec, double) == Quantity!(RadiusSpec, double)));

    static assert(is(Metre.Dimension == Kilometre.Dimension));
    static assert(is(Metre.Dimension == InternationalFoot.Dimension));
    static assert(is(Metre.Dimension == USSurveyFoot.Dimension));

    static assert(Metre.Scale.num == 1 && Metre.Scale.den == 1);
    static assert(Kilometre.Scale.num == 1000 && Kilometre.Scale.den == 1);
    static assert(InternationalFoot.Scale.num == 381 && InternationalFoot.Scale.den == 1250);
    static assert(USSurveyFoot.Scale.num == 1200 && USSurveyFoot.Scale.den == 3937);

    static assert(Quantity!(LengthSpec, double).sizeof == double.sizeof);
    static assert(Quantity!(RadiusSpec, long).sizeof == long.sizeof);

    enum q = fromCanonical!LengthSpec(12.5);
    static assert(q.value == 12.5);
}
