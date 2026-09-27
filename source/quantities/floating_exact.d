module quantities.floating_exact;

import core.stdc.string : memcpy;

private:
struct Binary64
{
    ulong significand;
    int exponent2;
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
ulong binary64Bits(double value)
{
    ulong bits;

    () @trusted {
        memcpy(&bits, &value, double.sizeof);
    }();

    return bits;
}

@safe pure nothrow @nogc
Binary64 decompose(double value)
{
    const bits = binary64Bits(value);
    const exponentField = cast(uint)((bits >> 52) & 0x7ffUL);
    const fraction = bits & ((1UL << 52) - 1UL);

    if (exponentField == 0)
        return Binary64(fraction, -1074);

    // rationalResultExactlyBinary64 excludes NaN and infinity first.
    assert(exponentField != 0x7ff);

    return Binary64(
        (1UL << 52) | fraction,
        cast(int) exponentField - 1023 - 52);
}

public:
@safe pure nothrow @nogc
bool rationalResultExactlyBinary64(
    double value,
    long numerator,
    long denominator)
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

    auto g = gcd(sig, d);
    sig /= g;
    d /= g;

    g = gcd(n, d);
    n /= g;
    d /= g;

    while ((d & 1UL) == 0)
        d >>= 1;

    if (d != 1UL)
        return false;

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

    enum ulong maxSignificand = (1UL << 53) - 1UL;
    if (n != 0 && sig > maxSignificand / n)
        return false;

    ulong product = sig * n;

    while (product != 0 && (product & 1UL) == 0)
    {
        product >>= 1;
        ++exponent2;
    }

    if (product > maxSignificand)
        return false;

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

    return exponent2 >= -1074;
}
