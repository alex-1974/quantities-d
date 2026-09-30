module r04_16_scalar_div_codegen;

import quantities;

extern(C):

double raw_scalar_div(double value, double scalar)
    @safe pure nothrow @nogc
{
    return value / scalar;
}

double quantity_scalar_div(double value, double scalar)
    @safe pure nothrow @nogc
{
    return (
        value.quantity!(Length, Metre)
        / scalar)
        .canonicalValue;
}
