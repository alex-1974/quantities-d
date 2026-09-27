module binary64_subnormal_double_round_probe;

import quantities.binary64_scale : scaleBinary64;
import std.math : ldexp;

@safe unittest
{
    // Exact source: 2950364274258428 * 2^-1074.
    // Exact scaled value:
    //
    //   2950364274258428 * 133 / 151 * 2^-1074
    //
    // Direct round-to-nearest, ties-to-even on the subnormal 2^-1074 lattice
    // yields 2598665221697821 quanta. A prior 53-bit normalization followed
    // by subnormal quantization yields 2598665221697820 instead: double
    // rounding by one ULP.
    const source = ldexp(2950364274258428.0, -1074);
    const expected = ldexp(2598665221697821.0, -1074);

    const scaled = scaleBinary64(source, 133, 151);

    assert(!scaled.overflow);
    assert(scaled.value == expected,
        "subnormal conversion must round the exact rational result only once");
}
