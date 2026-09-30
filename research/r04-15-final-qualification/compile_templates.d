module r04_15_compile_templates;

import quantities;

struct RatioSpec
{
    alias Dimension = Dimensionless;
    alias CanonicalUnit = DerivedUnit!(
        Dimensionless,
        ExactRatio!(1, 1));
}

struct QuotientLength
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    template QuotientWith(Rhs)
    {
        alias QuotientWith = RatioSpec;
    }
}

extern(C)
double compile_templates(double a, double b)
    @safe pure nothrow @nogc
{
    auto sum =
        a.quantity!(Length, Metre)
        + b.quantity!(Length, Metre);

    auto difference =
        a.quantity!(Length, Metre)
        - b.quantity!(Length, Metre);

    auto scaled =
        sum * 1.5;

    auto product =
        a.quantity!(Length, Metre)
        * b.quantity!(Length, Metre);

    auto quotient =
        a.quantity!(QuotientLength, Metre)
        / b.quantity!(QuotientLength, Metre);

    return sum.canonicalValue
        + difference.canonicalValue
        + scaled.canonicalValue
        + product.canonicalValue
        + quotient.canonicalValue;
}
