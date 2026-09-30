module quantities.r04_17_probe_11_real_ieee;

import quantities.real_scale :
    rescaleProductReal,
    rescaleQuotientReal,
    supportsExactRealRescale;

private enum Kind
{
    zero,
    finite,
    infinity,
    nan
}

private Kind classify(real value)
{
    if (value != value)
        return Kind.nan;
    if (value == real.infinity || value == -real.infinity)
        return Kind.infinity;
    if (value == 0.0L)
        return Kind.zero;
    return Kind.finite;
}

private bool negativeZero(real value)
{
    if (value != 0.0L)
        return false;

    return (1.0L / value) == -real.infinity;
}

private void compareSpecial(
    bool product,
    real lhs,
    real rhs)
{
    const actual =
        product
        ? rescaleProductReal(lhs, rhs, 2, 3)
        : rescaleQuotientReal(lhs, rhs, 2, 3);

    const native =
        product ? lhs * rhs : lhs / rhs;

    assert(classify(actual) == classify(native));

    final switch (classify(native))
    {
        case Kind.nan:
            break;

        case Kind.zero:
            assert(negativeZero(actual) == negativeZero(native));
            break;

        case Kind.infinity:
            assert(
                (actual < 0.0L)
                == (native < 0.0L));
            break;

        case Kind.finite:
            // Special-value dispatcher is only checked when a special operand
            // participates, so finite native results can only be signed zero
            // adjacent cases already covered by exact equality here.
            assert(actual == native);
            break;
    }
}

void main()
{
    static assert(supportsExactRealRescale);

    const values = [
        0.0L,
        -0.0L,
        1.0L,
        -1.0L,
        real.infinity,
        -real.infinity,
        real.nan,
    ];

    size_t cases;

    foreach (lhs; values)
    {
        foreach (rhs; values)
        {
            const special =
                lhs == 0.0L ||
                rhs == 0.0L ||
                lhs != lhs ||
                rhs != rhs ||
                lhs == real.infinity ||
                lhs == -real.infinity ||
                rhs == real.infinity ||
                rhs == -real.infinity;

            if (!special)
                continue;

            compareSpecial(true, lhs, rhs);
            compareSpecial(false, lhs, rhs);
            cases += 2;
        }
    }

    // Identity/native real arithmetic remains CTFE-capable.
    enum nativeProduct = 1.5L * 2.0L;
    enum nativeQuotient = 3.0L / 2.0L;
    static assert(nativeProduct == 3.0L);
    static assert(nativeQuotient == 1.5L);

    import std.stdio : writeln;
    writeln("R04.17 Probe 11 PASS: ", cases,
        " real IEEE-special comparisons");
}
