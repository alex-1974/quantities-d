module r04_15_codegen;

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

extern(C):

double raw_add(double a, double b)
    @safe pure nothrow @nogc
{
    return a + b;
}

double quantity_add(double a, double b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(Length, Metre)
        + b.quantity!(Length, Metre))
        .canonicalValue;
}

double raw_sub(double a, double b)
    @safe pure nothrow @nogc
{
    return a - b;
}

double quantity_sub(double a, double b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(Length, Metre)
        - b.quantity!(Length, Metre))
        .canonicalValue;
}

double raw_scalar_mul(double a, double b)
    @safe pure nothrow @nogc
{
    return a * b;
}

double quantity_scalar_mul(double a, double b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(Length, Metre)
        * b)
        .canonicalValue;
}

double raw_product(double a, double b)
    @safe pure nothrow @nogc
{
    return a * b;
}

double quantity_product(double a, double b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(Length, Metre)
        * b.quantity!(Length, Metre))
        .canonicalValue;
}

double raw_quotient(double a, double b)
    @safe pure nothrow @nogc
{
    return a / b;
}

double quantity_quotient(double a, double b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(QuotientLength, Metre)
        / b.quantity!(QuotientLength, Metre))
        .canonicalValue;
}
