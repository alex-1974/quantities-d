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
            const source = f[1].to!long;
            const r = longToFloating!float(source);
            writeln(r.status, " ", floatBits(r.value));
        }
        else if (op == "LD")
        {
            const source = f[1].to!long;
            const r = longToFloating!double(source);
            writeln(r.status, " ", doubleBits(r.value));
        }
        else if (op == "FD")
        {
            const source = floatFromBits(f[1].to!uint);
            const r = floatingToFloating!(float, double)(source);
            writeln(r.status, " ", doubleBits(r.value));
        }
        else if (op == "DF")
        {
            const source = doubleFromBits(f[1].to!ulong);
            const r = floatingToFloating!(double, float)(source);
            writeln(r.status, " ", floatBits(r.value));
        }
        else if (op == "FL")
        {
            const source = floatFromBits(f[1].to!uint);
            const r = floatingToLong(source);
            writeln(r.status, " ", r.value);
        }
        else if (op == "DL")
        {
            const source = doubleFromBits(f[1].to!ulong);
            const r = floatingToLong(source);
            writeln(r.status, " ", r.value);
        }
        else
        {
            assert(false, "unknown op");
        }
    }
}
