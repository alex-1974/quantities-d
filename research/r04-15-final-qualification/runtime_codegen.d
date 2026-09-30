module r04_15_runtime_codegen;

import core.stdc.time : clock;
import std.algorithm : sort;
import std.stdio : writeln;
import quantities;

alias Kernel = extern(C) double function(double, double) @safe pure nothrow @nogc;

extern(C):

double raw_add(double a, double b)
    @safe pure nothrow @nogc
{
    return a + b;
}

double quantity_add(double a, double b)
    @safe pure nothrow @nogc
{
    return (
        a.quantity!(Length, Metre)
        + b.quantity!(Length, Metre))
        .canonicalValue;
}

private ulong runKernel(Kernel kernel, size_t iterations, ref double checksum)
{
    double x = 1.0;
    double y = 0.00000011920928955078125; // exactly 2^-23

    const start = clock();

    foreach (_; 0 .. iterations)
    {
        x = kernel(x, y);
        y += 0.000000059604644775390625; // exactly 2^-24
    }

    const stop = clock();
    checksum += x + y;

    return cast(ulong)(stop - start);
}

void main()
{
    enum rounds = 11;
    enum iterations = 20_000_000;

    ulong[rounds] rawTimes;
    ulong[rounds] quantityTimes;
    double checksum;

    // Warm-up both paths.
    runKernel(&raw_add, 1_000_000, checksum);
    runKernel(&quantity_add, 1_000_000, checksum);

    foreach (round; 0 .. rounds)
    {
        if ((round & 1) == 0)
        {
            rawTimes[round] =
                runKernel(&raw_add, iterations, checksum);
            quantityTimes[round] =
                runKernel(&quantity_add, iterations, checksum);
        }
        else
        {
            quantityTimes[round] =
                runKernel(&quantity_add, iterations, checksum);
            rawTimes[round] =
                runKernel(&raw_add, iterations, checksum);
        }
    }

    auto rawSorted = rawTimes[];
    auto quantitySorted = quantityTimes[];
    rawSorted.sort();
    quantitySorted.sort();

    const rawMedian = rawSorted[rounds / 2];
    const quantityMedian = quantitySorted[rounds / 2];
    const ratio =
        cast(double)quantityMedian /
        cast(double)rawMedian;

    writeln("checksum: ", checksum);
    writeln("raw median ticks: ", rawMedian);
    writeln("quantity median ticks: ", quantityMedian);
    writeln("quantity/raw median ratio: ", ratio);

    // Broad materiality gate. Probe 9 already records exact instruction shape;
    // this only rejects a surprisingly large runtime penalty.
    assert(ratio <= 1.10,
        "R04.15 Probe 9B: Quantity add has >10% runtime penalty");

    writeln("R04.15 Probe 9B PASS: no material runtime penalty");
}
