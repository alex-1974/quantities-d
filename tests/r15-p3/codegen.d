module quantities.r15_p3_codegen;

import quantities;
import quantities.exact_conversion :
    convertFloatingUnits,
    convertIntegralUnits;

alias QuarterMetre = DerivedUnit!(LengthDimension, ExactRatio!(1, 4));

extern(C) long p3_codegen_ref_long_identity(long value)
    @safe pure nothrow @nogc
{
    return value;
}

extern(C) long p3_codegen_api_long_identity(long value)
    @safe pure nothrow @nogc
{
    const result = value.checkedQuantityAs!(Length, Metre, long);
    Quantity!(Length, long) output;
    return result.tryValue(output) ? output.canonicalValue : long.min;
}

extern(C) long p3_codegen_kernel_long_identity(long value)
    @safe pure nothrow @nogc
{
    const result = convertIntegralUnits!(Metre, Metre)(
        value, false, RoundingMode.towardZero);
    return result.hasValue ? result.value : long.min;
}

extern(C) long p3_codegen_api_quarter(long value)
    @safe pure nothrow @nogc
{
    const result = value.checkedQuantityAs!(Length, QuarterMetre, long);
    Quantity!(Length, long) output;
    return result.tryValue(output) ? output.canonicalValue : long.min;
}

extern(C) long p3_codegen_kernel_quarter(long value)
    @safe pure nothrow @nogc
{
    const result = convertIntegralUnits!(QuarterMetre, Metre)(
        value, false, RoundingMode.towardZero);
    return result.hasValue ? result.value : long.min;
}

extern(C) float p3_codegen_api_double_to_float(double value)
    @safe pure nothrow @nogc
{
    const result = value.checkedQuantityAs!(Length, Metre, float);
    Quantity!(Length, float) output;
    return result.tryValue(output) ? output.canonicalValue : float.nan;
}

extern(C) float p3_codegen_kernel_double_to_float(double value)
    @safe pure nothrow @nogc
{
    const result = convertFloatingUnits!(float, Metre, Metre)(value);
    return result.status == ConversionStatus.exact
        || result.status == ConversionStatus.inexact
        ? result.value
        : float.nan;
}
