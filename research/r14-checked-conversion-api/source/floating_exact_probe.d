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
