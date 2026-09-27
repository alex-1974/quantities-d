module exact_subnormal_rounding_probe;

import std.math : ldexp;

private:
@safe pure nothrow @nogc
ulong gcd(ulong a, ulong b)
{
    while (b != 0)
    {
        const r = a % b;
        a = b;
        b = r;
    }
    return a;
}

struct RoundedQuotient
{
    ulong value;
    bool inexact;
}

@safe pure nothrow @nogc
RoundedQuotient roundNearestTiesEven(
    ulong numerator,
    ulong denominator)
{
    assert(denominator != 0);

    const q = numerator / denominator;
    const r = numerator % denominator;

    if (r == 0)
        return RoundedQuotient(q, false);

    // Compare 2*r with denominator without overflowing.
    const half = denominator / 2;
    bool roundUp;

    if ((denominator & 1UL) == 0)
    {
        if (r > half)
            roundUp = true;
        else if (r == half)
            roundUp = (q & 1UL) != 0;
    }
    else
    {
        // Odd denominators have no exact halfway remainder.
        roundUp = r > half;
    }

    return RoundedQuotient(q + (roundUp ? 1UL : 0UL), true);
}

@safe pure nothrow @nogc
ulong scaleAndRoundQuanta(
    ulong sourceQuanta,
    ulong numerator,
    ulong denominator)
{
    assert(denominator != 0);

    // Cross-cancel before multiplication.
    const g1 = gcd(sourceQuanta, denominator);
    sourceQuanta /= g1;
    denominator /= g1;

    const g2 = gcd(numerator, denominator);
    numerator /= g2;
    denominator /= g2;

    // This focused probe keeps values tiny; general checked multiplication
    // belongs to the full kernel.
    assert(numerator == 0
        || sourceQuanta <= ulong.max / numerator);

    return roundNearestTiesEven(
        sourceQuanta * numerator,
        denominator).value;
}

@safe pure nothrow @nogc
double quantaToDouble(ulong quanta)
{
    return ldexp(cast(double) quanta, -1074);
}

@safe unittest
{
    enum minSubnormal =
        double.min_normal * double.epsilon;

    // Exact integer/rational rounding decisions.
    static assert(scaleAndRoundQuanta(1, 1, 2) == 0);
    static assert(scaleAndRoundQuanta(1, 3, 2) == 2);
    static assert(scaleAndRoundQuanta(1, 5, 2) == 2);
    static assert(scaleAndRoundQuanta(1, 7, 2) == 4);

    // Ties-to-even in both directions.
    static assert(scaleAndRoundQuanta(3, 1, 2) == 2);
    static assert(scaleAndRoundQuanta(5, 1, 2) == 2);
    static assert(scaleAndRoundQuanta(7, 1, 2) == 4);

    // Only after the exact rounding decision do we construct binary64.
    enum half = quantaToDouble(
        scaleAndRoundQuanta(1, 1, 2));
    enum threeHalves = quantaToDouble(
        scaleAndRoundQuanta(1, 3, 2));
    enum fiveHalves = quantaToDouble(
        scaleAndRoundQuanta(1, 5, 2));
    enum sevenHalves = quantaToDouble(
        scaleAndRoundQuanta(1, 7, 2));

    static assert(half == 0.0);
    static assert(threeHalves == minSubnormal * 2.0);
    static assert(fiveHalves == minSubnormal * 2.0);
    static assert(sevenHalves == minSubnormal * 4.0);

    assert(quantaToDouble(
        scaleAndRoundQuanta(1, 1, 2)) == 0.0);
    assert(quantaToDouble(
        scaleAndRoundQuanta(1, 3, 2))
        == minSubnormal * 2.0);
    assert(quantaToDouble(
        scaleAndRoundQuanta(1, 5, 2))
        == minSubnormal * 2.0);
    assert(quantaToDouble(
        scaleAndRoundQuanta(1, 7, 2))
        == minSubnormal * 4.0);
}
