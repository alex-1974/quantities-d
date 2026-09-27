module ucent_probe;

import core.int128 : Cent, mul, udivmod;

@safe pure nothrow @nogc
Cent fromUlong(ulong value)
{
    return Cent(value, 0);
}

@safe pure nothrow @nogc
Cent multiply(ulong a, ulong b)
{
    return mul(fromUlong(a), fromUlong(b));
}

@safe pure nothrow @nogc
bool equal(Cent a, Cent b)
{
    return a.lo == b.lo && a.hi == b.hi;
}

@safe pure nothrow @nogc
bool isZero(Cent value)
{
    return value.lo == 0 && value.hi == 0;
}

@safe pure nothrow @nogc
Cent divideWithRemainder(Cent numerator, ulong denominator, out Cent remainder)
{
    return udivmod(numerator, fromUlong(denominator), remainder);
}

@safe unittest
{
    // Baseline 64x64 -> 128 multiplication and unsigned division/remainder.
    enum a = cast(ulong) long.max;
    enum b = cast(ulong) long.max - 2UL;
    enum product = multiply(a, b);

    static assert(product.hi != 0);

    enum quotientAndRemainder = ()
    {
        Cent remainder;
        const quotient = divideWithRemainder(product, b, remainder);
        return [quotient, remainder];
    }();

    static assert(equal(quotientAndRemainder[0], fromUlong(a)));
    static assert(isZero(quotientAndRemainder[1]));

    // Representative binary64-ratio shape:
    // 2^52 * long.max / (long.max - 2).
    enum significand = 1UL << 52;
    enum ratioNumerator = cast(ulong) long.max;
    enum ratioDenominator = cast(ulong)(long.max - 2);
    enum scaled = multiply(significand, ratioNumerator);

    enum scaledQR = ()
    {
        Cent remainder;
        const quotient =
            divideWithRemainder(scaled, ratioDenominator, remainder);
        return [quotient, remainder];
    }();

    static assert(scaledQR[0].hi == 0);
    static assert(scaledQR[0].lo == significand);
    static assert(!isZero(scaledQR[1]));

    // The quotient is still 2^52. The +1 comes from the final
    // round-to-nearest, ties-to-even decision based on the remainder.
    enum doubledRemainder = mul(scaledQR[1], fromUlong(2));
    enum denominator128 = fromUlong(ratioDenominator);

    static assert(
        doubledRemainder.hi > denominator128.hi
        || (doubledRemainder.hi == denominator128.hi
            && doubledRemainder.lo > denominator128.lo));

    enum roundedSignificand = scaledQR[0].lo + 1;
    static assert(roundedSignificand == significand + 1);

    // Runtime must match CTFE exactly.
    const runtimeProduct = multiply(a, b);
    assert(equal(runtimeProduct, product));

    Cent runtimeRemainder;
    const runtimeQuotient =
        divideWithRemainder(runtimeProduct, b, runtimeRemainder);
    assert(equal(runtimeQuotient, fromUlong(a)));
    assert(isZero(runtimeRemainder));

    const runtimeScaled = multiply(significand, ratioNumerator);
    Cent runtimeScaledRemainder;
    const runtimeScaledQuotient =
        divideWithRemainder(
            runtimeScaled, ratioDenominator, runtimeScaledRemainder);
    assert(equal(runtimeScaledQuotient, scaledQR[0]));
    assert(equal(runtimeScaledRemainder, scaledQR[1]));
}
