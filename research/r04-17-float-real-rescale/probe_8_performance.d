module r04_17_probe_8_performance;

import core.stdc.time : clock;
import std.algorithm : sort;
import std.stdio : writeln;

import quantities;
import quantities.binary32_scale :
    rescaleProductBinary32,
    rescaleQuotientBinary32;

alias Kernel = float function(float, float) @safe pure nothrow @nogc;

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

@safe pure nothrow @nogc
float exactProduct(float a, float b)
{
    return rescaleProductBinary32(a, b, 2, 3);
}

@safe pure nothrow @nogc
float quantityProduct(float a, float b)
{
    return (
        a.quantity!(ProductLength, Metre)
        * b.quantity!(ProductLength, Metre))
        .canonicalValue;
}

@safe pure nothrow @nogc
float sequentialProduct(float a, float b)
{
    return (a * b) * (2.0f / 3.0f);
}

@safe pure nothrow @nogc
float exactQuotient(float a, float b)
{
    return rescaleQuotientBinary32(a, b, 2, 3);
}

@safe pure nothrow @nogc
float quantityQuotient(float a, float b)
{
    return (
        a.quantity!(QuotientLength, Metre)
        / b.quantity!(QuotientLength, Metre))
        .canonicalValue;
}

@safe pure nothrow @nogc
float sequentialQuotient(float a, float b)
{
    return (a / b) * (2.0f / 3.0f);
}

private uint nextState(ref uint state)
{
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}

private float finitePositive(uint bits)
{
    // Keep workload normal, finite, nonzero, and broad enough to exercise
    // varying significands/exponents without special-value dispatch.
    const exp = 100U + ((bits >> 23) % 55U);
    const frac = bits & 0x007f_ffffU;
    const raw = (exp << 23) | frac;

    float result;
    () @trusted {
        import core.stdc.string : memcpy;
        memcpy(&result, &raw, float.sizeof);
    }();
    return result;
}

private ulong run(
    Kernel kernel,
    const(float)[] lhs,
    const(float)[] rhs,
    size_t iterations,
    ref double checksum)
{
    float acc = 1.0f;
    const start = clock();

    foreach (i; 0 .. iterations)
    {
        const j = i & (lhs.length - 1);
        acc += kernel(lhs[j], rhs[j]);
        if (acc > 1.0e30f || acc != acc)
            acc = 1.0f;
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

private void benchmarkPair(
    string label,
    Kernel direct,
    Kernel wrapped,
    const(float)[] lhs,
    const(float)[] rhs,
    ref double checksum)
{
    enum rounds = 9;
    enum iterations = 2_000_000;

    ulong[rounds] directTimes;
    ulong[rounds] wrappedTimes;

    run(direct, lhs, rhs, 100_000, checksum);
    run(wrapped, lhs, rhs, 100_000, checksum);

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

    const directMedian = median(directTimes[]);
    const wrappedMedian = median(wrappedTimes[]);
    const ratio = cast(double)wrappedMedian / cast(double)directMedian;

    writeln(label, " direct median ticks: ", directMedian);
    writeln(label, " quantity median ticks: ", wrappedMedian);
    writeln(label, " quantity/direct ratio: ", ratio);

    // This is an abstraction-overhead tripwire, not a kernel performance
    // target. Both sides execute identical exact represented-source semantics.
    assert(ratio <= 1.15,
        "Quantity wrapper adds >15% over the exact binary32 kernel");
}

private void benchmarkContext(
    string label,
    Kernel exact,
    Kernel sequential,
    const(float)[] lhs,
    const(float)[] rhs,
    ref double checksum)
{
    enum rounds = 7;
    enum iterations = 2_000_000;

    ulong[rounds] exactTimes;
    ulong[rounds] sequentialTimes;

    run(exact, lhs, rhs, 100_000, checksum);
    run(sequential, lhs, rhs, 100_000, checksum);

    foreach (r; 0 .. rounds)
    {
        if ((r & 1) == 0)
        {
            exactTimes[r] = run(exact, lhs, rhs, iterations, checksum);
            sequentialTimes[r] = run(sequential, lhs, rhs, iterations, checksum);
        }
        else
        {
            sequentialTimes[r] = run(sequential, lhs, rhs, iterations, checksum);
            exactTimes[r] = run(exact, lhs, rhs, iterations, checksum);
        }
    }

    const e = median(exactTimes[]);
    const n = median(sequentialTimes[]);
    writeln(label, " exact median ticks: ", e);
    writeln(label, " sequential median ticks: ", n);
    writeln(label, " exact/sequential context ratio: ",
        cast(double)e / cast(double)n);
}

void main()
{
    enum size_t N = 4096;
    float[N] lhs;
    float[N] rhs;

    uint state = 0x6d2b79f5U;
    foreach (i; 0 .. N)
    {
        lhs[i] = finitePositive(nextState(state));
        rhs[i] = finitePositive(nextState(state));
    }

    double checksum;

    benchmarkPair(
        "product",
        &exactProduct,
        &quantityProduct,
        lhs[],
        rhs[],
        checksum);

    benchmarkPair(
        "quotient",
        &exactQuotient,
        &quantityQuotient,
        lhs[],
        rhs[],
        checksum);

    // Context only: these sequential expressions are NOT semantically
    // equivalent to the exact-once-rounded contract.
    benchmarkContext(
        "product",
        &exactProduct,
        &sequentialProduct,
        lhs[],
        rhs[],
        checksum);

    benchmarkContext(
        "quotient",
        &exactQuotient,
        &sequentialQuotient,
        lhs[],
        rhs[],
        checksum);

    writeln("checksum: ", checksum);
    writeln("R04.17 Probe 8 PASS: no material Quantity abstraction overhead");
}
