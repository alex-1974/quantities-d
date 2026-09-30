module r15_probe_6_runner;

import std.conv : to;
import std.math : ldexp;
import std.stdio : stdin, writeln;
import std.string : split, strip;

import r15_real_identity_conversion;

private void writeRealResult(RealResult r)
{
    if (r.status == R15RealStatus.nonFinite
        || r.status == R15RealStatus.overflow)
    {
        writeln(r.status, " -");
        return;
    }

    const p = decomposeReal(r.value);

    if (p.zero)
    {
        writeln(r.status, " zero ", p.negative ? 1 : 0);
        return;
    }

    writeln(
        r.status,
        " ",
        p.negative ? 1 : 0,
        " ",
        p.significand,
        " ",
        p.exponent2);
}

void main()
{
    foreach (line; stdin.byLineCopy)
    {
        const f = line.strip.split;
        if (f.length == 0)
            continue;

        const op = f[0];

        if (op == "LR")
        {
            auto source = f[1].to!long;
            writeRealResult(longToReal(source));
        }
        else if (op == "DR")
        {
            union U
            {
                ulong bits;
                double value;
            }

            U u;
            u.bits = f[1].to!ulong;
            writeRealResult(doubleToReal(u.value));
        }
        else
        {
            const bool negative = f[1] == "1";
            const ulong sig = f[2].to!ulong;
            const int exp2 = f[3].to!int;
            const real source =
                realFromParts(sig, exp2, negative);

            if (op == "RD")
            {
                const r = realToDouble(source);

                if (r.status == R15RealStatus.overflow
                    || r.status == R15RealStatus.nonFinite)
                    writeln(r.status, " -");
                else
                    writeln(r.status, " ", rawDoubleBits(r.value));
            }
            else
            {
                assert(op == "RL");
                const r = realToLong(source);

                if (r.status == R15RealStatus.exact)
                    writeln(r.status, " ", r.value);
                else
                    writeln(r.status, " -");
            }
        }
    }
}
