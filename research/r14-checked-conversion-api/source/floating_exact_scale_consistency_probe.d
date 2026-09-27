module floating_exact_scale_consistency_probe;

import quantities.binary64_scale : scaleBinary64;
import quantities.floating_exact : rationalResultExactlyBinary64;

@safe unittest
{
    const minSubnormal = double.min_normal * double.epsilon;

    struct Case
    {
        double value;
        long numerator;
        long denominator;
        bool expectedExact;
        bool expectedOverflow;
    }

    const cases = [
        Case(1.0, 1, 2, true, false),
        Case(1.0, 1, 10, false, false),
        Case(-1.0, 1, 2, true, false),
        Case(3.0, 1, 2, true, false),

        Case(minSubnormal, 1, 1, true, false),
        Case(minSubnormal, 1, 2, false, false),
        Case(minSubnormal, 3, 2, false, false),
        Case(-minSubnormal, 1, 2, false, false),

        Case(double.min_normal,
            9007199254740991L,
            9007199254740992L,
            false,
            false),
        Case(double.min_normal,
            18014398509481983L,
            18014398509481984L,
            false,
            false),

        Case(double.max, 1, 1, true, false),
        Case(double.max,
            18014398509481984L,
            18014398509481983L,
            false,
            false),
        Case(double.max,
            18014398509481983L,
            18014398509481982L,
            false,
            true),
        Case(double.max, 2, 1, false, true)
    ];

    foreach (c; cases)
    {
        const exact = rationalResultExactlyBinary64(
            c.value, c.numerator, c.denominator);
        const scaled = scaleBinary64(
            c.value, c.numerator, c.denominator);

        assert(exact == c.expectedExact);
        assert(scaled.overflow == c.expectedOverflow);

        if (scaled.overflow)
            assert(!exact);
    }
}


@safe unittest
{
    // Deterministic cross-product stress matrix. This is intentionally not a
    // random/fuzz test: every input is stable across compilers and exercises a
    // distinct binary64 magnitude or rational-scale shape.
    const minSubnormal = double.min_normal * double.epsilon;
    const largestSubnormal = double.min_normal - minSubnormal;

    const values = [
        minSubnormal,
        largestSubnormal,
        double.min_normal,
        0.1,
        0.5,
        1.0,
        1.5,
        3.0,
        9007199254740991.0, // 2^53 - 1, exactly representable
        double.max
    ];

    struct Ratio
    {
        long numerator;
        long denominator;
    }

    const ratios = [
        Ratio(1, 1),
        Ratio(2, 1),
        Ratio(1, 2),
        Ratio(4, 8),
        Ratio(3, 2),
        Ratio(2, 3),
        Ratio(1, 10),
        Ratio(10, 1),
        Ratio(133, 151),
        Ratio(long.max, long.max),
        Ratio(long.max - 1, long.max),
        Ratio(long.min, long.max)
    ];

    foreach (value; values)
    {
        foreach (ratio; ratios)
        {
            const positiveExact = rationalResultExactlyBinary64(
                value, ratio.numerator, ratio.denominator);
            const positiveScaled = scaleBinary64(
                value, ratio.numerator, ratio.denominator);

            const negativeExact = rationalResultExactlyBinary64(
                -value, ratio.numerator, ratio.denominator);
            const negativeScaled = scaleBinary64(
                -value, ratio.numerator, ratio.denominator);

            // Exact representability is sign-symmetric.
            assert(positiveExact == negativeExact);

            // Overflow depends on magnitude, not source sign.
            assert(positiveScaled.overflow == negativeScaled.overflow);

            // An overflowing result cannot be exact binary64.
            if (positiveScaled.overflow)
                assert(!positiveExact);

            // For finite nonzero results, sign symmetry must hold numerically.
            if (!positiveScaled.overflow && positiveScaled.value != 0.0)
                assert(negativeScaled.value == -positiveScaled.value);
        }
    }

    // Algebraically identical rational scales must produce identical value and
    // exactness classifications, including reduction before risky arithmetic.
    foreach (value; values)
    {
        const a = scaleBinary64(value, 1, 2);
        const b = scaleBinary64(value, 4, 8);
        assert(a.overflow == b.overflow);
        if (!a.overflow)
            assert(a.value == b.value);

        assert(rationalResultExactlyBinary64(value, 1, 2)
            == rationalResultExactlyBinary64(value, 4, 8));

        const identity = scaleBinary64(value, long.max, long.max);
        assert(!identity.overflow);
        assert(identity.value == value);
        assert(rationalResultExactlyBinary64(
            value, long.max, long.max));
    }
}
