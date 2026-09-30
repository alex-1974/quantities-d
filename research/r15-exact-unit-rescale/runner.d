module r15_rescale_runner;

import r15_rescale_kernel;
import std.conv : to;
import std.math : ldexp;
import std.stdio : stdin, writeln;
import std.string : split;

@safe pure nothrow @nogc
void attributeProbe()
{
    double source = 1;
    auto d = convert!double(source, 2, 3);
    auto f = convert!float(source, 2, 3);
    assert(d.status == Status.inexact && f.status == Status.inexact);
}

void emit(T, S)(S source, long n, long d)
{
    const r = convert!T(source, n, d);
    if (r.status == Status.overflow || r.status == Status.nonFinite)
        writeln(r.status, " -");
    else
        writeln(r.status, " ", storedBits(r.value));
}

void main(string[] args)
{
    if (args.length > 1)
    {
        writeln(real.mant_dig, " ", real.min_exp, " ", real.max_exp);
        return;
    }
    attributeProbe();
    foreach (line; stdin.byLineCopy)
    {
        const f = line.split;
        const op = f[0];
        const n = f[$ - 2].to!long;
        const d = f[$ - 1].to!long;
        if (op[0] == 'L')
        {
            auto source = f[1].to!long;
            if (op[1] == 'F') emit!float(source, n, d);
            else emit!double(source, n, d);
        }
        else if (op[0] == 'U')
        {
            auto source = f[1].to!ulong;
            if (op[1] == 'F') emit!float(source, n, d);
            else emit!double(source, n, d);
        }
        else if (op[0] == 'F')
        {
            auto source = fromBits!float(f[1].to!ulong);
            if (op[1] == 'F') emit!float(source, n, d);
            else emit!double(source, n, d);
        }
        else if (op[0] == 'D')
        {
            auto source = fromBits!double(f[1].to!ulong);
            if (op[1] == 'F') emit!float(source, n, d);
            else emit!double(source, n, d);
        }
        else if (op[0] == 'R')
        {
            static if ((real.mant_dig == 64 && real.min_exp == -16381 &&
                        real.max_exp == 16384) ||
                       (real.mant_dig == 53 && real.min_exp == -1021 &&
                        real.max_exp == 1024))
            {
                real source = ldexp(cast(real)f[1].to!ulong, f[2].to!int);
                if (f[3] == "1") source = -source;
                if (op[1] == 'F') emit!float(source, n, d);
                else emit!double(source, n, d);
            }
            else assert(false, "unsupported real source format");
        }
        else assert(false, "unknown source");
    }
}
