module app;

struct ExactRatio(long N, long D)
{
    static assert(D != 0, "ExactRatio denominator must not be zero.");
    enum numerator = N;
    enum denominator = D;
}

struct LengthDimension {}

struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1);
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

void main()
{
    static assert(isUnit!Metre);
    static assert(isQuantitySpec!Length);
    static assert(Quantity!(Length, double).sizeof == double.sizeof);

    enum q = Quantity!(Length, double)(12.5);
    static assert(q.value == 12.5);
}
