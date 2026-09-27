module floating_exact;

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
    const bool negative = value < 0.0;
    double x = negative ? -value : value;

    if (x == 0.0)
        return Binary64(0, 0, negative);

    // Normalize arithmetically into [1, 2) without bit reinterpretation so
    // the path remains CTFE-compatible on the D baseline compilers.
    int exponent2 = 0;
    while (x >= 2.0)
    {
        x *= 0.5;
        ++exponent2;
    }
    while (x < 1.0)
    {
        x *= 2.0;
        --exponent2;
    }

    // A binary64 normal significand has 53 precision bits including the
    // implicit leading bit. Multiplying a normalized value by 2^52 therefore
    // yields its exact integer significand for finite normal values.
    ulong significand = 0;
    double scaled = x;
    foreach (_; 0 .. 52)
        scaled *= 2.0;
    significand = cast(ulong) scaled;

    return Binary64(significand, exponent2 - 52, negative);
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

    // Remove powers of two from the integer factors because they can be
    // transferred into the binary exponent without consuming significand bits.
    int exponent2 = parts.exponent2;
    while ((sig & 1UL) == 0)
    {
        sig >>= 1;
        ++exponent2;
    }
    while ((n & 1UL) == 0)
    {
        n >>= 1;
        ++exponent2;
    }

    // The remaining odd significand product must fit into binary64's 53-bit
    // precision. Avoid forming a potentially overflowing product merely to
    // test this bound.
    enum ulong maxSignificand = (1UL << 53) - 1UL;
    if (n != 0 && sig > maxSignificand / n)
        return false;

    ulong product = sig * n;

    // Normalize any newly exposed powers of two after multiplication.
    while (product != 0 && (product & 1UL) == 0)
    {
        product >>= 1;
        ++exponent2;
    }

    if (product > maxSignificand)
        return false;

    // Highest represented bit plus exponent must stay within finite binary64.
    // Lowest exact non-zero binary64 value is 1 * 2^-1074.
    int highestBit = -1;
    ulong scan = product;
    while (scan != 0)
    {
        scan >>= 1;
        ++highestBit;
    }

    if (product == 0)
        return true;

    const int topExponent = exponent2 + highestBit;
    if (topExponent > 1023)
        return false;

    if (exponent2 < -1074)
    {
        // Values below the subnormal quantum can still be representable if
        // the significand contains enough powers of two, but those were
        // normalized away above. Therefore this is below binary64 range.
        return false;
    }

    return true;
}

public:
