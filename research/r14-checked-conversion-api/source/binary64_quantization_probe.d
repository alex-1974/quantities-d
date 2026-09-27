module binary64_quantization_probe;

import std.math : frexp, ldexp;

private enum int precisionBits = 53;
private enum int minQuantumExponent = -1074;
private enum int minNormalExponent = -1022;
private enum int maxNormalExponent = 1023;

private:
@safe pure nothrow @nogc
double quantizeBinary64(double value)
{
    if (value == 0.0)
        return value;

    const bool negative = value < 0.0;
    double x = negative ? -value : value;

    // This probe targets finite positive magnitudes produced by the rational
    // kernel. Non-finite policy remains outside the quantizer.
    if (!(x <= double.max))
        return value;

    int exponent;
    double fraction = frexp(x, exponent);

    // frexp gives x = fraction * 2^exponent, 0.5 <= fraction < 1.
    // Normal binary64 already has at most 53 significant bits. Rebuilding
    // through ldexp is enough except below the minimum subnormal quantum,
    // where baseline CTFE may retain excess precision.
    if (exponent > minNormalExponent)
        return value;

    // Express the magnitude in units of the minimum binary64 quantum 2^-1074.
    // Values in this region are small enough that the quotient is bounded by
    // 2^52 and therefore exactly integral-representable in binary64 once
    // rounded.
    double quanta = ldexp(x, -minQuantumExponent);

    // Explicit round-to-nearest, ties-to-even without runtime allocation or
    // bit reinterpretation. The cast truncates because quanta is non-negative.
    ulong lower = cast(ulong) quanta;
    double remainder = quanta - cast(double) lower;

    if (remainder > 0.5
        || (remainder == 0.5 && (lower & 1UL) != 0))
        ++lower;

    double rounded = ldexp(cast(double) lower, minQuantumExponent);
    return negative ? -rounded : rounded;
}

@safe unittest
{
    enum minSubnormal = double.min_normal * double.epsilon;

    enum halfMin = quantizeBinary64(minSubnormal / 2.0);
    static assert(halfMin == 0.0);

    enum exactMin = quantizeBinary64(minSubnormal);
    static assert(exactMin == minSubnormal);

    enum oneAndHalfMin = quantizeBinary64(minSubnormal * 1.5);
    static assert(oneAndHalfMin == minSubnormal * 2.0);

    enum twoAndHalfMin = quantizeBinary64(minSubnormal * 2.5);
    static assert(twoAndHalfMin == minSubnormal * 2.0);

    enum threeAndHalfMin = quantizeBinary64(minSubnormal * 3.5);
    static assert(threeAndHalfMin == minSubnormal * 4.0);

    enum minNormal = quantizeBinary64(double.min_normal);
    static assert(minNormal == double.min_normal);

    enum ordinary = quantizeBinary64(1.5);
    static assert(ordinary == 1.5);

    enum maximum = quantizeBinary64(double.max);
    static assert(maximum == double.max);

    const runtimeMinSubnormal = double.min_normal * double.epsilon;
    assert(quantizeBinary64(runtimeMinSubnormal / 2.0) == 0.0);
    assert(quantizeBinary64(runtimeMinSubnormal) == runtimeMinSubnormal);
}
