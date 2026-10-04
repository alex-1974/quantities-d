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

private ulong runLong(string mode)(ulong iterations, ulong seed)
{
    ulong state = seed;
    ulong checksum;
    foreach (_; 0 .. iterations)
    {
        const raw = next(state);
        long value = cast(long)(raw & 0x3ffffffffffffffcUL);
        if ((raw & 0x4000000000000000UL) != 0)
            value = -value;

        static if (mode == "ref-long-id")
            const result = p3RefLongIdentity(value);
        else static if (mode == "api-long-id")
            const result = p3ApiLongIdentity(value);
        else static if (mode == "kernel-long-id")
            const result = p3KernelLongIdentity(value);
        else static if (mode == "api-quarter")
            const result = p3ApiQuarter(value);
        else
            const result = p3KernelQuarter(value);

        checksum = (checksum << 7) ^ (checksum >> 3) ^ cast(ulong)result;
    }
    return checksum;
}

private ulong runFloat(string mode)(ulong iterations, ulong seed)
{
    ulong state = seed;
    ulong checksum;
    foreach (_; 0 .. iterations)
    {
        const raw = next(state);
        const double value = cast(double)(raw & 0x00ffffffUL);

        static if (mode == "api-double-float")
            const result = p3ApiDoubleToFloatIdentity(value);
        else
            const result = p3KernelDoubleToFloatIdentity(value);

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

    if (mode == "ref-long-id")
        writeln(runLong!"ref-long-id"(iterations, seed));
    else if (mode == "kernel-long-id")
        writeln(runLong!"kernel-long-id"(iterations, seed));
    else if (mode == "api-long-id")
        writeln(runLong!"api-long-id"(iterations, seed));
    else if (mode == "kernel-quarter")
        writeln(runLong!"kernel-quarter"(iterations, seed));
    else if (mode == "api-quarter")
        writeln(runLong!"api-quarter"(iterations, seed));
    else if (mode == "kernel-double-float")
        writeln(runFloat!"kernel-double-float"(iterations, seed));
    else if (mode == "api-double-float")
        writeln(runFloat!"api-double-float"(iterations, seed));
    else
        writeln("unknown mode");
}
