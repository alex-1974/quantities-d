module quantities.ratio;

/// Exact normalized compile-time rational value.
struct ExactRatio(long Numerator, long Denominator)
{
    static assert(Denominator != 0,
        "ExactRatio denominator must not be zero.");

private:
    @safe pure nothrow @nogc
    static ulong magnitude(long value)
    {
        if (value >= 0)
            return cast(ulong) value;

        return cast(ulong)(-(value + 1)) + 1UL;
    }

    @safe pure nothrow @nogc
    static ulong gcd(ulong a, ulong b)
    {
        while (b != 0)
        {
            const remainder = a % b;
            a = b;
            b = remainder;
        }
        return a;
    }

    enum bool negative = (Numerator < 0) != (Denominator < 0);
    enum ulong numeratorMagnitude = magnitude(Numerator);
    enum ulong denominatorMagnitude = magnitude(Denominator);
    enum ulong divisor = gcd(numeratorMagnitude, denominatorMagnitude);
    enum ulong reducedNumerator =
        divisor == 0 ? 0 : numeratorMagnitude / divisor;
    enum ulong reducedDenominator =
        divisor == 0 ? 1 : denominatorMagnitude / divisor;

    static assert(reducedDenominator <= cast(ulong) long.max,
        "ExactRatio normalized denominator is not representable in long.");

    static assert(
        negative
            ? reducedNumerator <= cast(ulong) long.max + 1UL
            : reducedNumerator <= cast(ulong) long.max,
        "ExactRatio normalized numerator is not representable in long.");

    enum long signedNumerator =
        reducedNumerator == 0 ? 0
        : negative && reducedNumerator == cast(ulong) long.max + 1UL
            ? long.min
            : negative
                ? -cast(long) reducedNumerator
                : cast(long) reducedNumerator;

public:
    enum long numerator = signedNumerator;
    enum long denominator = cast(long) reducedDenominator;
}

@safe unittest
{
    alias Half = ExactRatio!(2, 4);
    static assert(Half.numerator == 1);
    static assert(Half.denominator == 2);

    alias NegativeHalf = ExactRatio!(1, -2);
    static assert(NegativeHalf.numerator == -1);
    static assert(NegativeHalf.denominator == 2);

    alias Zero = ExactRatio!(0, long.min);
    static assert(Zero.numerator == 0);
    static assert(Zero.denominator == 1);

    alias MinReduced = ExactRatio!(long.min, long.min);
    static assert(MinReduced.numerator == 1);
    static assert(MinReduced.denominator == 1);
}
