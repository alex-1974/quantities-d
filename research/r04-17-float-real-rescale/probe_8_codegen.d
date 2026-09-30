module r04_17_probe_8_codegen;

import quantities;
import quantities.binary32_scale :
    rescaleProductBinary32,
    rescaleQuotientBinary32;

alias ScaledAreaUnit = DerivedUnit!(
    AreaDimension,
    ExactRatio!(3, 2));

struct ScaledArea
{
    alias Dimension = AreaDimension;
    alias CanonicalUnit = ScaledAreaUnit;
}

struct ProductLength
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    template ProductWith(Rhs)
    {
        alias ProductWith = ScaledArea;
    }
}

alias ScaledUnitless = DerivedUnit!(
    Dimensionless,
    ExactRatio!(3, 2));

struct ScaledRatio
{
    alias Dimension = Dimensionless;
    alias CanonicalUnit = ScaledUnitless;
}

struct QuotientLength
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    template QuotientWith(Rhs)
    {
        alias QuotientWith = ScaledRatio;
    }
}

extern(C):

float direct_product(float a, float b)
    @safe pure nothrow @nogc
{
    return rescaleProductBinary32(a, b, 2, 3);
}

float quantity_product(float a, float b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(ProductLength, Metre)
        * b.quantity!(ProductLength, Metre))
        .canonicalValue;
}

float direct_quotient(float a, float b)
    @safe pure nothrow @nogc
{
    return rescaleQuotientBinary32(a, b, 2, 3);
}

float quantity_quotient(float a, float b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(QuotientLength, Metre)
        / b.quantity!(QuotientLength, Metre))
        .canonicalValue;
}
