module binary64_overflow_boundary_probe;

import quantities.binary64_scale : scaleBinary64;

@safe unittest
{
    // double.max = (2^53 - 1) * 2^971.
    // The round-to-nearest overflow midpoint is
    //
    //   double.max + 2^970
    //
    // so midpoint / double.max is exactly
    //
    //   (2^54 - 1) / (2 * (2^53 - 1))
    // = 18014398509481983 / 18014398509481982.
    //
    // A ratio immediately below the midpoint must still round to double.max;
    // the midpoint itself and values above it round to +infinity.

    const below = scaleBinary64(
        double.max,
        18014398509481982L,
        18014398509481981L);
    assert(!below.overflow,
        "finite exact value below overflow midpoint must round to double.max");
    assert(below.value == double.max);

    const midpoint = scaleBinary64(
        double.max,
        18014398509481983L,
        18014398509481982L);
    assert(midpoint.overflow,
        "overflow midpoint must round to infinity");

    const above = scaleBinary64(
        double.max,
        18014398509481984L,
        18014398509481983L);
    assert(above.overflow,
        "value above overflow midpoint must round to infinity");
}
