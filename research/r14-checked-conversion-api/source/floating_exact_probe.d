module floating_exact_probe;

import common : ConversionStatus;

private:
struct Binary64
{
    ulong significand;
    int exponent2;
    bool negative;
}

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

@safe pure nothrow @nogc
Binary64 decompose(double value)
{
    union Bits
    {
        double value;
        ulong raw;
    }

    Bits bits;
    bits.value = value;

    const sign = (bits.raw >> 63) != 0;
    const rawExp = cast(uint)((bits.raw >> 52) & 0x7ffUL);
    const fraction = bits.raw & ((1UL << 52) - 1UL);

    if (rawExp == 0)
    {
        // Subnormal: value = fraction * 2^-1074.
        return Binary64(fraction, -1074, sign);
    }

    // Normal: value = (2^52 + fraction) * 2^(rawExp-1023-52).
    return Binary64(
        (1UL << 52) | fraction,
        cast(int) rawExp - 1023 - 52,
        sign);
}

@safe pure nothrow @nogc
bool rationalResultExactlyBinary64(double value, long numerator, long denominator)
{
    if (value == 0.0)
        return true;
    if (value != value)
        return false;
    if (value > double.max || value < -double.max)
        return false;
    if (denominator == 0 || numerator == 0)
        return numerator == 0;

    auto parts = decompose(value);

    ulong n = numerator < 0
        ? cast(ulong)(-(numerator + 1)) + 1UL
        : cast(ulong) numerator;
    ulong d = denominator < 0
        ? cast(ulong)(-(denominator + 1)) + 1UL
        : cast(ulong) denominator;

    ulong sig = parts.significand;

    // Cancel source significand against rational denominator first.
    auto g = gcd(sig, d);
    sig /= g;
    d /= g;

    // Cancel numerator/denominator.
    g = gcd(n, d);
    n /= g;
    d /= g;

    // Binary floating can absorb any remaining factor of two in denominator.
    while ((d & 1UL) == 0)
        d >>= 1;

    // Any remaining odd denominator makes the exact result non-binary.
    if (d != 1UL)
        return false;

    // Precision/range of sig*n is deliberately left as the next probe gate.
    // The current test only establishes denominator exactness.
    return true;
}

public:
@safe unittest
{
    enum identity = rationalResultExactlyBinary64(1.5, 1, 1);
    static assert(identity);

    enum half = rationalResultExactlyBinary64(3.0, 1, 2);
    static assert(half);

    enum tenth = rationalResultExactlyBinary64(1.0, 1, 10);
    static assert(!tenth);

    // The represented binary value of 0.1 multiplied by 10 is a rational whose
    // denominator factors may cancel against the represented significand.
    enum representedTenthTimesTen =
        rationalResultExactlyBinary64(0.1, 10, 1);
    static assert(representedTenthTimesTen);

    enum third = rationalResultExactlyBinary64(1.0, 1, 3);
    static assert(!third);

    enum zero = rationalResultExactlyBinary64(0.0, 1, 3);
    static assert(zero);
}
