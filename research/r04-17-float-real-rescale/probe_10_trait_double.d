module r04_17_probe_10_trait_double;

import core.stdc.string : memcpy;
import std.stdio : writeln;

import quantities.binary64_scale :
    rescaleProductBinary64,
    rescaleQuotientBinary64;

import r04_17_real80_kernel :
    rescaleProductDoubleTrait,
    rescaleQuotientDoubleTrait;

private double fromBits(ulong bits)
    @safe pure nothrow @nogc
{
    double value;
    () @trusted {
        memcpy(&value, &bits, double.sizeof);
    }();
    return value;
}

private ulong bitsOf(double value)
    @safe pure nothrow @nogc
{
    ulong bits;
    () @trusted {
        memcpy(&bits, &value, double.sizeof);
    }();
    return bits;
}

private ulong nextState(ref ulong state)
    @safe pure nothrow @nogc
{
    state ^= state >> 12;
    state ^= state << 25;
    state ^= state >> 27;
    return state * 0x2545_f491_4f6c_dd1dUL;
}

private ulong finiteNonzeroBits(ref ulong state)
    @safe pure nothrow @nogc
{
    while (true)
    {
        const bits = nextState(state);
        const exp = (bits >> 52) & 0x7ffUL;
        const frac = bits & 0x000f_ffff_ffff_ffffUL;

        if (exp != 0x7ffUL
            && (exp != 0 || frac != 0))
            return bits;
    }
}

void main()
{
    ulong state = 0x9e37_79b9_7f4a_7c15UL;
    size_t comparisons;

    foreach (_; 0 .. 20_000)
    {
        const a = fromBits(finiteNonzeroBits(state));
        const b = fromBits(finiteNonzeroBits(state));

        const n =
            cast(long)(
                (nextState(state) & 0x7fff_ffff_ffff_ffffUL)
                | 1UL);
        const d =
            cast(long)(
                (nextState(state) & 0x7fff_ffff_ffff_ffffUL)
                | 1UL);

        const pTrait =
            rescaleProductDoubleTrait(a, b, n, d);
        const pReference =
            rescaleProductBinary64(a, b, n, d);

        assert(bitsOf(pTrait) == bitsOf(pReference));
        ++comparisons;

        const qTrait =
            rescaleQuotientDoubleTrait(a, b, n, d);
        const qReference =
            rescaleQuotientBinary64(a, b, n, d);

        assert(bitsOf(qTrait) == bitsOf(qReference));
        ++comparisons;
    }

    const specials = [
        0.0,
        -0.0,
        1.0,
        -1.0,
        double.infinity,
        -double.infinity,
        double.nan,
    ];

    foreach (a; specials)
    {
        foreach (b; specials)
        {
            const pTrait =
                rescaleProductDoubleTrait(a, b, 2, 3);
            const pReference =
                rescaleProductBinary64(a, b, 2, 3);

            if (pReference != pReference)
                assert(pTrait != pTrait);
            else
                assert(bitsOf(pTrait) == bitsOf(pReference));

            const qTrait =
                rescaleQuotientDoubleTrait(a, b, 2, 3);
            const qReference =
                rescaleQuotientBinary64(a, b, 2, 3);

            if (qReference != qReference)
                assert(qTrait != qTrait);
            else
                assert(bitsOf(qTrait) == bitsOf(qReference));

            comparisons += 2;
        }
    }

    writeln(
        "R04.17 Probe 10 PASS: ",
        comparisons,
        " trait-kernel binary64 comparisons");
}
