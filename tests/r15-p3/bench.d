module quantities.r15_p3_bench;

import quantities;
import quantities.exact_conversion :
    convertFloatingUnits,
    convertIntegralUnits;

import std.conv : to;
import std.stdio : writeln;

alias QuarterMetre = DerivedUnit!(LengthDimension, ExactRatio!(1, 4));

extern(C) long p3RefLongIdentity(long value)
    @safe pure nothrow @nogc
{
    return value;
}

extern(C) long p3ApiLongIdentity(long value)
    @safe pure nothrow @nogc
{
    const result = value.checkedQuantityAs!(Length, Metre, long);
    Quantity!(Length, long) output;
    return result.tryValue(output) ? output.canonicalValue : long.min;
}

extern(C) long p3KernelLongIdentity(long value)
    @safe pure nothrow @nogc
{
    const result = convertIntegralUnits!(Metre, Metre)(
        value, false, RoundingMode.towardZero);
    return result.hasValue ? result.value : long.min;
}

extern(C) long p3ApiQuarter(long value)
    @safe pure nothrow @nogc
{
    const result = value.checkedQuantityAs!(Length, QuarterMetre, long);
    Quantity!(Length, long) output;
    return result.tryValue(output) ? output.canonicalValue : long.min;
}

extern(C) long p3KernelQuarter(long value)
    @safe pure nothrow @nogc
{
    const result = convertIntegralUnits!(QuarterMetre, Metre)(
        value, false, RoundingMode.towardZero);
    return result.hasValue ? result.value : long.min;
}

extern(C) float p3ApiDoubleToFloatIdentity(double value)
    @safe pure nothrow @nogc
{
    const result = value.checkedQuantityAs!(Length, Metre, float);
    Quantity!(Length, float) output;
    return result.tryValue(output) ? output.canonicalValue : float.nan;
}

extern(C) float p3KernelDoubleToFloatIdentity(double value)
    @safe pure nothrow @nogc
{
    const result = convertFloatingUnits!(float, Metre, Metre)(value);
    return result.status == ConversionStatus.exact
        || result.status == ConversionStatus.inexact
        ? result.value
        : float.nan;
}

private ulong next(ref ulong state) @safe pure nothrow @nogc
{
    state = state * 6364136223846793005UL + 1442695040888963407UL;
    return state;
}

private ulong runLong(string mode, ulong iterations, ulong seed)
{
    ulong state = seed;
    ulong checksum;
    foreach (_; 0 .. iterations)
    {
        const raw = next(state);
        long value = cast(long)(raw & 0x3ffffffffffffffcUL);
        if ((raw & 0x4000000000000000UL) != 0)
            value = -value;

        long result;
        if (mode == "ref-long-id")
            result = p3RefLongIdentity(value);
        else if (mode == "api-long-id")
            result = p3ApiLongIdentity(value);
        else if (mode == "kernel-long-id")
            result = p3KernelLongIdentity(value);
        else if (mode == "api-quarter")
            result = p3ApiQuarter(value);
        else
            result = p3KernelQuarter(value);

        checksum = (checksum << 7) ^ (checksum >> 3) ^ cast(ulong)result;
    }
    return checksum;
}

private ulong runFloat(string mode, ulong iterations, ulong seed)
{
    ulong state = seed;
    ulong checksum;
    foreach (_; 0 .. iterations)
    {
        const raw = next(state);
        const double value = cast(double)(raw & 0x00ffffffUL);
        const float result = mode == "api-double-float"
            ? p3ApiDoubleToFloatIdentity(value)
            : p3KernelDoubleToFloatIdentity(value);
        checksum = (checksum << 7) ^ (checksum >> 3) ^ cast(ulong)result;
    }
    return checksum;
}

void main(string[] args)
{
    if (args.length != 4)
    {
        writeln("usage: bench <mode> <iterations> <seed>");
        return;
    }

    const mode = args[1];
    const iterations = args[2].to!ulong;
    const seed = args[3].to!ulong;

    if (mode == "api-double-float" || mode == "kernel-double-float")
        writeln(runFloat(mode, iterations, seed));
    else
        writeln(runLong(mode, iterations, seed));
}
