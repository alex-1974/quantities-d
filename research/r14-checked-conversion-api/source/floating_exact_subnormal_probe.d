module floating_exact_subnormal_probe;

import quantities.floating_exact : rationalResultExactlyBinary64;
import quantities.binary64_scale : scaleBinary64;

@safe unittest
{
    const minSubnormal = double.min_normal * double.epsilon;

    const exact = rationalResultExactlyBinary64(minSubnormal, 3, 2);
    const scaled = scaleBinary64(minSubnormal, 3, 2);

    assert(!exact, "minSubnormal * 3/2 must be inexact on binary64");
    assert(!scaled.overflow);
    assert(scaled.value == minSubnormal * 2.0);
}
