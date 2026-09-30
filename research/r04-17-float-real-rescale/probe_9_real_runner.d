module r04_17_probe_9_real_runner;

import std.conv : to;
import std.math : ldexp;
import std.stdio : stdin, writeln;
import std.string : split, strip;

import r04_17_real80_kernel :
    decomposeReal,
    rescaleProductReal,
    rescaleQuotientReal;

void main()
{
    foreach (line; stdin.byLineCopy)
    {
        const f = line.strip.split;
        if (f.length == 0)
            continue;

        const op = f[0];
        const lhsSig = f[1].to!ulong;
        const lhsExp = f[2].to!int;
        const rhsSig = f[3].to!ulong;
        const rhsExp = f[4].to!int;
        const n = f[5].to!long;
        const d = f[6].to!long;

        const lhs = ldexp(cast(real)lhsSig, lhsExp);
        const rhs = ldexp(cast(real)rhsSig, rhsExp);

        const result =
            op == "P"
            ? rescaleProductReal(lhs, rhs, n, d)
            : rescaleQuotientReal(lhs, rhs, n, d);

        if (result != result)
        {
            writeln("nan");
        }
        else if (result == real.infinity)
        {
            writeln("+inf");
        }
        else if (result == -real.infinity)
        {
            writeln("-inf");
        }
        else if (result == 0.0L)
        {
            writeln(result < 0.0L ? "-zero" : "+zero");
        }
        else
        {
            const exact = decomposeReal(result);
            writeln(
                exact.negative ? "-" : "+",
                " ",
                exact.significand,
                " ",
                exact.exponent2);
        }
    }
}
