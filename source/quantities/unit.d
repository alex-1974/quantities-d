module quantities.unit;

import quantities.dimension :
    DivideDimension,
    MultiplyDimension,
    PowerDimension;
import quantities.ratio : ExactRatio;
import quantities.traits : isUnit;

private ulong magnitude(long value) @safe pure nothrow @nogc
{
    if (value >= 0)
        return cast(ulong)value;
    return cast(ulong)(-(value + 1)) + 1UL;
}

private ulong gcd(ulong a, ulong b) @safe pure nothrow @nogc
{
    while (b != 0)
    {
        const remainder = a % b;
        a = b;
        b = remainder;
    }
    return a;
}

private template MultiplyRatio(A, B)
{
    enum g1 = gcd(magnitude(A.numerator), cast(ulong)B.denominator);
    enum g2 = gcd(magnitude(B.numerator), cast(ulong)A.denominator);

    enum aNum = A.numerator / cast(long)(g1 == 0 ? 1 : g1);
    enum bDen = B.denominator / cast(long)(g1 == 0 ? 1 : g1);
    enum bNum = B.numerator / cast(long)(g2 == 0 ? 1 : g2);
    enum aDen = A.denominator / cast(long)(g2 == 0 ? 1 : g2);

    static assert(
        magnitude(aNum) == 0 ||
        magnitude(bNum) <= ulong.max / magnitude(aNum),
        "derived unit scale numerator exceeds ExactRatio's supported range");
    static assert(
        cast(ulong)aDen == 0 ||
        cast(ulong)bDen <= cast(ulong)long.max / cast(ulong)aDen,
        "derived unit scale denominator exceeds ExactRatio's supported range");

    // ExactRatio performs the final normalization and sign handling.
    alias MultiplyRatio = ExactRatio!(
        aNum * bNum,
        aDen * bDen);
}

private template DivideRatio(A, B)
{
    static assert(B.numerator != 0,
        "cannot divide by a zero unit scale");

    alias Reciprocal = ExactRatio!(B.denominator, B.numerator);
    alias DivideRatio = MultiplyRatio!(A, Reciprocal);
}

private template PositivePowerRatio(A, uint Power)
{
    static if (Power == 0)
        alias PositivePowerRatio = ExactRatio!(1, 1);
    else static if (Power == 1)
        alias PositivePowerRatio = A;
    else static if ((Power & 1) == 0)
    {
        alias Half = PositivePowerRatio!(A, Power / 2);
        alias PositivePowerRatio = MultiplyRatio!(Half, Half);
    }
    else
    {
        alias Rest = PositivePowerRatio!(A, Power - 1);
        alias PositivePowerRatio = MultiplyRatio!(A, Rest);
    }
}

private template PowerRatio(A, int Power)
{
    static if (Power >= 0)
        alias PowerRatio = PositivePowerRatio!(A, cast(uint)Power);
    else
    {
        static assert(Power != int.min,
            "unit exponent int.min is not supported");
        static assert(A.numerator != 0,
            "cannot raise a zero unit scale to a negative power");
        alias Reciprocal = ExactRatio!(A.denominator, A.numerator);
        alias PowerRatio =
            PositivePowerRatio!(Reciprocal, cast(uint)(-Power));
    }
}

/// Generic compile-time unit formed from a physical Dimension and exact Scale.
struct DerivedUnit(DimensionT, ScaleT)
{
    alias Dimension = DimensionT;
    alias Scale = ScaleT;
}

/// Product of two units, including exact scale propagation.
template MultiplyUnit(A, B)
{
    static assert(isUnit!A && isUnit!B,
        "MultiplyUnit operands must be valid units.");

    alias MultiplyUnit = DerivedUnit!(
        MultiplyDimension!(A.Dimension, B.Dimension),
        MultiplyRatio!(A.Scale, B.Scale));
}

/// Quotient of two units, including exact scale propagation.
template DivideUnit(A, B)
{
    static assert(isUnit!A && isUnit!B,
        "DivideUnit operands must be valid units.");

    alias DivideUnit = DerivedUnit!(
        DivideDimension!(A.Dimension, B.Dimension),
        DivideRatio!(A.Scale, B.Scale));
}

/// Integral power of a unit, including exact scale exponentiation.
template PowerUnit(A, int Power)
{
    static assert(isUnit!A,
        "PowerUnit operand must be a valid unit.");

    alias PowerUnit = DerivedUnit!(
        PowerDimension!(A.Dimension, Power),
        PowerRatio!(A.Scale, Power));
}

@safe unittest
{
    import quantities.dimension : BaseDimension;

    struct LengthTag {}
    struct TimeTag {}

    alias LengthDimension = BaseDimension!LengthTag;
    alias TimeDimension = BaseDimension!TimeTag;

    struct Metre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 1);
    }

    struct Millimetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 1000);
    }

    struct Kilometre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1000, 1);
    }

    struct Second
    {
        alias Dimension = TimeDimension;
        alias Scale = ExactRatio!(1, 1);
    }

    struct Hour
    {
        alias Dimension = TimeDimension;
        alias Scale = ExactRatio!(3600, 1);
    }

    alias SquareMillimetre = PowerUnit!(Millimetre, 2);
    static assert(SquareMillimetre.Scale.numerator == 1);
    static assert(SquareMillimetre.Scale.denominator == 1_000_000);

    alias SquareKilometre = PowerUnit!(Kilometre, 2);
    static assert(SquareKilometre.Scale.numerator == 1_000_000);
    static assert(SquareKilometre.Scale.denominator == 1);

    alias KilometresPerHour = DivideUnit!(Kilometre, Hour);
    static assert(KilometresPerHour.Scale.numerator == 5);
    static assert(KilometresPerHour.Scale.denominator == 18);

    alias MetresPerSecond = DivideUnit!(Metre, Second);
    alias Acceleration = DivideUnit!(MetresPerSecond, Second);
    static assert(Acceleration.Scale.numerator == 1);
    static assert(Acceleration.Scale.denominator == 1);

    alias KilometresPerSecondSquared =
        DivideUnit!(Kilometre, PowerUnit!(Second, 2));
    static assert(KilometresPerSecondSquared.Scale.numerator == 1000);
    static assert(KilometresPerSecondSquared.Scale.denominator == 1);

    // Cross-cancellation must happen before multiplication.
    alias A = DerivedUnit!(
        LengthDimension,
        ExactRatio!(long.max, 2));
    alias B = DerivedUnit!(
        LengthDimension,
        ExactRatio!(2, long.max));
    alias Product = MultiplyUnit!(A, B);
    static assert(Product.Scale.numerator == 1);
    static assert(Product.Scale.denominator == 1);
}
