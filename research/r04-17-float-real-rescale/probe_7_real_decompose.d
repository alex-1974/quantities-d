module r04_17_probe_7_real_decompose;

import std.algorithm.comparison : min;
import std.math : frexp, ldexp;
import std.math.operations : nextDown, nextUp;
import std.stdio : writeln;

struct RealExact
{
    ulong significand;
    int exponent2;
    bool negative;
}

@safe pure nothrow @nogc
RealExact decomposeReal(real value)
{
    assert(value != 0.0L);
    assert(value == value);
    assert(value != real.infinity);
    assert(value != -real.infinity);

    int exponent;
    real fraction = frexp(value, exponent);

    const negative = fraction < 0.0L;
    if (negative)
        fraction = -fraction;

    static assert(real.mant_dig <= 64,
        "Probe 7 only tests real formats whose significand fits ulong.");

    const scaled =
        ldexp(fraction, real.mant_dig);

    const significand = cast(ulong)scaled;

    // If this equality fails, frexp/ldexp + ulong is not an exact represented-
    // source decomposition for the current real format.
    assert(cast(real)significand == scaled);

    return RealExact(
        significand,
        exponent - real.mant_dig,
        negative);
}

@safe pure nothrow @nogc
real reconstructReal(RealExact exact)
{
    real value =
        ldexp(
            cast(real)exact.significand,
            exact.exponent2);

    return exact.negative ? -value : value;
}

@safe pure nothrow @nogc
void checkRoundTrip(real value)
{
    const exact = decomposeReal(value);
    const reconstructed = reconstructReal(exact);
    assert(reconstructed == value);
}

void main()
{
    static if (
        real.mant_dig == 53
        && real.min_exp == -1021
        && real.max_exp == 1024)
    {
        writeln("real format class: binary64-like");
    }
    else static if (
        real.mant_dig == 64
        && real.min_exp == -16381
        && real.max_exp == 16384)
    {
        writeln("real format class: x87 extended / real80 property set");
    }
    else static if (
        real.mant_dig == 113
        && real.min_exp == -16381
        && real.max_exp == 16384)
    {
        writeln("real format class: binary128-like");
    }
    else
    {
        writeln("real format class: other");
    }

    writeln(
        "real props: sizeof=", real.sizeof,
        " mant_dig=", real.mant_dig,
        " min_exp=", real.min_exp,
        " max_exp=", real.max_exp);

    static if (real.mant_dig <= 64)
    {
        const real minSubnormal =
            ldexp(
                1.0L,
                real.min_exp - real.mant_dig);

        const fixed = [
            1.0L,
            -1.0L,
            1.0L + real.epsilon,
            nextUp(1.0L),
            nextDown(1.0L),
            real.min_normal,
            -real.min_normal,
            minSubnormal,
            -minSubnormal,
            real.max,
            -real.max,
        ];

        foreach (value; fixed)
            checkRoundTrip(value);

        enum int p = real.mant_dig;

        static if (p == 64)
            enum ulong significandMask = ulong.max;
        else
            enum ulong significandMask = (1UL << p) - 1;

        enum ulong topBit = 1UL << (p - 1);

        ulong state = 0x9e37_79b9_7f4a_7c15UL;

        foreach (i; 0 .. 20_000)
        {
            // xorshift64* state; only deterministic coverage matters here.
            state ^= state >> 12;
            state ^= state << 25;
            state ^= state >> 27;

            ulong significand =
                (state * 0x2545_f491_4f6c_dd1dUL)
                & significandMask;

            significand |= topBit;

            const int span =
                min(1000, (real.max_exp / 4));

            const int exponent2 =
                cast(int)(state % cast(ulong)(2 * span + 1))
                - span
                - (p - 1);

            const real value =
                ldexp(
                    cast(real)significand,
                    exponent2);

            if (value == 0.0L
                || value == real.infinity)
                continue;

            const exact = decomposeReal(value);

            assert(exact.significand == significand);
            assert(exact.exponent2 == exponent2);
            assert(!exact.negative);
            assert(reconstructReal(exact) == value);
        }

        writeln(
            "R04.17 Probe 7 PASS: layout-free real decomposition "
            "round-trips on current <=64-bit significand format");
    }
    else
    {
        writeln(
            "R04.17 Probe 7 SKIP: current real significand exceeds ulong");
    }
}
