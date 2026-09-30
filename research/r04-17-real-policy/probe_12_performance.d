module quantities.r04_17_probe_12_real_perf;

import core.stdc.time : clock;
import std.algorithm : sort;
import std.math : ldexp;
import std.stdio : writeln;

import quantities;
import quantities.real_scale :
    rescaleProductReal,
    rescaleQuotientReal,
    supportsExactRealRescale;

alias Kernel = real function(real, real) @safe pure nothrow @nogc;

alias ScaledAreaUnit = DerivedUnit!(
    AreaDimension,
    ExactRatio!(3, 2));

struct ScaledArea
{
    alias Dimension = AreaDimension;
    alias CanonicalUnit = ScaledAreaUnit;
}

struct ProductLength
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    template ProductWith(Rhs)
    {
        alias ProductWith = ScaledArea;
    }
}

alias ScaledUnitless = DerivedUnit!(
    Dimensionless,
    ExactRatio!(3, 2));

struct ScaledRatio
{
    alias Dimension = Dimensionless;
    alias CanonicalUnit = ScaledUnitless;
}

struct QuotientLength
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    template QuotientWith(Rhs)
    {
        alias QuotientWith = ScaledRatio;
    }
}

real directProduct(real a, real b)
    @safe pure nothrow @nogc
{
    return rescaleProductReal(a, b, 2, 3);
}

real quantityProduct(real a, real b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(ProductLength, Metre)
        * b.quantity!(ProductLength, Metre))
        .canonicalValue;
}

real directQuotient(real a, real b)
    @safe pure nothrow @nogc
{
    return rescaleQuotientReal(a, b, 2, 3);
}

real quantityQuotient(real a, real b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(QuotientLength, Metre)
        / b.quantity!(QuotientLength, Metre))
        .canonicalValue;
}

private ulong nextState(ref ulong state)
{
    state ^= state >> 12;
    state ^= state << 25;
    state ^= state >> 27;
    return state * 0x2545_f491_4f6c_dd1dUL;
}

private real makeValue(ref ulong state)
{
    ulong sig = nextState(state);
    sig |= 1UL << 63;

    const int exponent2 =
        -70 + cast(int)(nextState(state) % 31UL);

    return ldexp(cast(real)sig, exponent2);
}

private ulong run(
    Kernel kernel,
    const(real)[] lhs,
    const(real)[] rhs,
    size_t iterations,
    ref real checksum)
{
    real acc = 0.0L;
    const start = clock();

    foreach (i; 0 .. iterations)
    {
        const j = i & (lhs.length - 1);
        acc += kernel(lhs[j], rhs[j]);
    }

    const stop = clock();
    checksum += acc;
    return cast(ulong)(stop - start);
}

private ulong median(ulong[] values)
{
    values.sort();
    return values[values.length / 2];
}

private void compare(
    string label,
    Kernel direct,
    Kernel wrapped,
    const(real)[] lhs,
    const(real)[] rhs,
    ref real checksum)
{
    enum rounds = 9;
    enum iterations = 300_000;

    ulong[rounds] directTimes;
    ulong[rounds] wrappedTimes;

    run(direct, lhs, rhs, 20_000, checksum);
    run(wrapped, lhs, rhs, 20_000, checksum);

    foreach (r; 0 .. rounds)
    {
        if ((r & 1) == 0)
        {
            directTimes[r] = run(direct, lhs, rhs, iterations, checksum);
            wrappedTimes[r] = run(wrapped, lhs, rhs, iterations, checksum);
        }
        else
        {
            wrappedTimes[r] = run(wrapped, lhs, rhs, iterations, checksum);
            directTimes[r] = run(direct, lhs, rhs, iterations, checksum);
        }
    }

    const d = median(directTimes[]);
    const q = median(wrappedTimes[]);
    const ratio = cast(double)q / cast(double)d;

    writeln(label, " direct median ticks: ", d);
    writeln(label, " quantity median ticks: ", q);
    writeln(label, " quantity/direct ratio: ", ratio);

    assert(ratio <= 1.15,
        "R04.17 real Quantity abstraction overhead > 15%");
}

void main()
{
    static assert(supportsExactRealRescale);

    enum size_t N = 1024;
    real[N] lhs;
    real[N] rhs;

    ulong state = 0x9e37_79b9_7f4a_7c15UL;

    foreach (i; 0 .. N)
    {
        lhs[i] = makeValue(state);
        rhs[i] = makeValue(state);
    }

    real checksum;

    compare(
        "product",
        &directProduct,
        &quantityProduct,
        lhs[],
        rhs[],
        checksum);

    compare(
        "quotient",
        &directQuotient,
        &quantityQuotient,
        lhs[],
        rhs[],
        checksum);

    writeln("checksum: ", checksum);
    writeln("R04.17 Probe 12 PASS: no material real Quantity overhead");
}
