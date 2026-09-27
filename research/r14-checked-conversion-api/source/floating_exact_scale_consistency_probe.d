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
