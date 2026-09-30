module r15_probe_5_runner;

import std.conv : to;
import std.stdio : stdin, writeln;
import std.string : split, strip;

import r15_identity_conversion_kernel;

void main()
{
    foreach (line; stdin.byLineCopy)
    {
        const f = line.strip.split;
        if (f.length == 0)
            continue;

        const op = f[0];

        if (op == "LF")
        {
            auto source = f[1].to!long;
            const r = longToFloating!float(source);
            writeln(r.status, " ", floatBits(r.value));
        }
        else if (op == "LD")
        {
            auto source = f[1].to!long;
            const r = longToFloating!double(source);
            writeln(r.status, " ", doubleBits(r.value));
        }
        else if (op == "FD")
        {
            auto source = floatFromBits(f[1].to!uint);
            const r = floatingToFloating!(float, double)(source);
            if (r.status == R15Status.overflow || r.status == R15Status.nonFinite)
                writeln(r.status, " -");
            else
                writeln(r.status, " ", doubleBits(r.value));
        }
        else if (op == "DF")
        {
            auto source = doubleFromBits(f[1].to!ulong);
            const r = floatingToFloating!(double, float)(source);
            if (r.status == R15Status.overflow || r.status == R15Status.nonFinite)
                writeln(r.status, " -");
            else
                writeln(r.status, " ", floatBits(r.value));
        }
        else if (op == "FL")
        {
            auto source = floatFromBits(f[1].to!uint);
            const r = floatingToLong(source);
            if (r.status == R15Status.exact)
                writeln(r.status, " ", r.value);
            else
                writeln(r.status, " -");
        }
        else if (op == "DL")
        {
            auto source = doubleFromBits(f[1].to!ulong);
            const r = floatingToLong(source);
            writeln(r.status, " ", r.value);
        }
        else
        {
            assert(false, "unknown op");
        }
    }
}
