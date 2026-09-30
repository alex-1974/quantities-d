module r15_integral_runner;
import r15_composed_kernel : convertComposedLong, IntegralRoundingMode;
import r15_rescale_kernel : Status;
import std.conv : to;
import std.stdio : stdin, writeln;
import std.string : split;

@safe pure nothrow @nogc
void attributes()
{
    const r = convertComposedLong(3,-1,true,1,1,1,1,true,
        IntegralRoundingMode.nearestTiesAway);
    assert(r.status == Status.inexact && r.hasValue && r.value == -2);
}

enum ctfe = convertComposedLong(1,63,true,1,1,1,1,false,
    IntegralRoundingMode.towardZero);
static assert(ctfe.status == Status.exact && ctfe.hasValue && ctfe.value == long.min);

void main()
{
    attributes();
    foreach (line; stdin.byLineCopy)
    {
        const f = line.split;
        const r = convertComposedLong(f[2].to!ulong, f[3].to!int, f[4] == "1",
            f[5].to!long, f[6].to!long, f[7].to!long, f[8].to!long,
            f[0] == "R", cast(IntegralRoundingMode)f[1].to!int);
        if (r.hasValue) writeln(r.status, " ", r.value);
        else writeln(r.status, " -");
    }
}
