module quantities.conversion;

import quantities.binary64_scale : scaleBinary64;
import quantities.floating_exact : rationalResultExactlyBinary64;
import quantities.quantity : Quantity;
import quantities.traits : isQuantitySpec, isUnit;

enum ConversionStatus
{
    exact,
    inexact,
    overflow,
    nonFinite
}

enum ExactFailure
{
    inexact,
    overflow,
    nonFinite
}

enum RoundingMode
{
    towardZero,
    floor,
    ceiling,
    nearestTiesAway
}

struct ConversionResult(T)
{
private:
    bool hasValue_;
    T value_;
    ConversionStatus status_;

public:
    @safe pure nothrow @nogc
    static ConversionResult withValue(T value, ConversionStatus status)
    {
        assert(status == ConversionStatus.exact
            || status == ConversionStatus.inexact);

        ConversionResult result;
        result.hasValue_ = true;
        result.value_ = value;
        result.status_ = status;
        return result;
    }

    @safe pure nothrow @nogc
    static ConversionResult withoutValue(ConversionStatus status)
    {
        assert(status != ConversionStatus.exact);

        ConversionResult result;
        result.status_ = status;
        return result;
    }

    @safe pure nothrow @nogc
    bool hasValue() const
    {
        return hasValue_;
    }

    @safe pure nothrow @nogc
    ConversionStatus status() const
    {
        return status_;
    }

    @safe pure nothrow @nogc
    bool tryValue(out T value) const
    {
        if (!hasValue_)
            return false;

        value = value_;
        return true;
    }
}

struct ExactResult(T)
{
private:
    bool hasValue_;
    T value_;
    ExactFailure failure_;

public:
    @safe pure nothrow @nogc
    static ExactResult success(T value)
    {
        ExactResult result;
        result.hasValue_ = true;
        result.value_ = value;
        return result;
    }

    @safe pure nothrow @nogc
    static ExactResult failed(ExactFailure failure)
    {
        ExactResult result;
        result.failure_ = failure;
        return result;
    }

    @safe pure nothrow @nogc
    bool hasValue() const
    {
        return hasValue_;
    }

    @safe pure nothrow @nogc
    bool tryValue(out T value) const
    {
        if (!hasValue_)
            return false;

        value = value_;
        return true;
    }

    @safe pure nothrow @nogc
    bool tryFailure(out ExactFailure failure) const
    {
        if (hasValue_)
            return false;

        failure = failure_;
        return true;
    }
}

private:
@safe pure nothrow @nogc
ulong magnitude(long value)
{
    return value >= 0
        ? cast(ulong) value
        : cast(ulong)(-(value + 1)) + 1UL;
}

@safe pure nothrow @nogc
ulong gcd(ulong a, ulong b)
{
    while (b != 0)
    {
        const remainder = a % b;
        a = b;
        b = remainder;
    }
    return a;
}

@safe pure nothrow @nogc
bool multiplyChecked(long a, long b, out long result)
{
    if (a == 0 || b == 0)
    {
        result = 0;
        return true;
    }

    if (a == long.min)
    {
        if (b == 1)
        {
            result = long.min;
            return true;
        }
        return false;
    }

    if (b == long.min)
    {
        if (a == 1)
        {
            result = long.min;
            return true;
        }
        return false;
    }

    const aa = a < 0 ? -a : a;
    const bb = b < 0 ? -b : b;
    if (aa > long.max / bb)
        return false;

    result = a * b;
    return true;
}

@safe pure nothrow @nogc
ConversionResult!long convertIntegral(
    long value,
    long numerator,
    long denominator,
    RoundingMode mode)
{
    assert(denominator > 0);

    ulong valueMagnitude = magnitude(value);
    ulong numeratorMagnitude = magnitude(numerator);
    ulong denominatorMagnitude = cast(ulong) denominator;

    auto divisor = gcd(valueMagnitude, denominatorMagnitude);
    valueMagnitude /= divisor;
    denominatorMagnitude /= divisor;

    divisor = gcd(numeratorMagnitude, denominatorMagnitude);
    numeratorMagnitude /= divisor;
    denominatorMagnitude /= divisor;

    const bool negative = (value < 0) != (numerator < 0);

    if (valueMagnitude > cast(ulong) long.max + (negative ? 1UL : 0UL)
        || numeratorMagnitude > cast(ulong) long.max + (negative ? 1UL : 0UL))
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    long signedValue;
    if (negative && valueMagnitude == cast(ulong) long.max + 1UL)
        signedValue = long.min;
    else
        signedValue = negative
            ? -cast(long) valueMagnitude
            : cast(long) valueMagnitude;

    if (numeratorMagnitude > cast(ulong) long.max)
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    long product;
    if (!multiplyChecked(signedValue, cast(long) numeratorMagnitude, product))
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    const long d = cast(long) denominatorMagnitude;
    const long quotient = product / d;
    const long remainder = product % d;

    if (remainder == 0)
        return ConversionResult!long.withValue(quotient, ConversionStatus.exact);

    long rounded = quotient;
    final switch (mode)
    {
        case RoundingMode.towardZero:
            break;
        case RoundingMode.floor:
            if (remainder < 0)
                --rounded;
            break;
        case RoundingMode.ceiling:
            if (remainder > 0)
                ++rounded;
            break;
        case RoundingMode.nearestTiesAway:
            const twice = magnitude(remainder) * 2UL;
            if (twice >= cast(ulong) d)
                rounded += product < 0 ? -1 : 1;
            break;
    }

    return ConversionResult!long.withValue(rounded, ConversionStatus.inexact);
}

@safe pure nothrow @nogc
ConversionResult!long convertIntegralChecked(
    long value,
    long numerator,
    long denominator)
{
    const converted = convertIntegral(
        value, numerator, denominator, RoundingMode.towardZero);

    if (converted.status == ConversionStatus.inexact)
        return ConversionResult!long.withoutValue(ConversionStatus.inexact);

    return converted;
}

@safe pure nothrow @nogc
ConversionResult!long convertIntegralUnits(FromUnit, ToUnit)(
    long value,
    RoundingMode mode)
{
    ulong a = magnitude(FromUnit.Scale.numerator);
    ulong b = cast(ulong) FromUnit.Scale.denominator;
    ulong c = magnitude(ToUnit.Scale.numerator);
    ulong d = cast(ulong) ToUnit.Scale.denominator;

    auto divisor = gcd(a, c);
    a /= divisor;
    c /= divisor;

    divisor = gcd(d, b);
    d /= divisor;
    b /= divisor;

    if (a > cast(ulong) long.max || b > cast(ulong) long.max
        || c > cast(ulong) long.max || d > cast(ulong) long.max)
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    long numerator;
    if (!multiplyChecked(cast(long) a, cast(long) d, numerator))
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    long denominator;
    if (!multiplyChecked(cast(long) b, cast(long) c, denominator))
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    const bool negative =
        (FromUnit.Scale.numerator < 0) != (ToUnit.Scale.numerator < 0);
    if (negative)
        numerator = -numerator;

    return convertIntegral(value, numerator, denominator, mode);
}

@safe pure nothrow @nogc
ConversionResult!long convertIntegralUnitsChecked(FromUnit, ToUnit)(long value)
{
    ulong a = magnitude(FromUnit.Scale.numerator);
    ulong b = cast(ulong) FromUnit.Scale.denominator;
    ulong c = magnitude(ToUnit.Scale.numerator);
    ulong d = cast(ulong) ToUnit.Scale.denominator;

    auto divisor = gcd(a, c);
    a /= divisor;
    c /= divisor;

    divisor = gcd(d, b);
    d /= divisor;
    b /= divisor;

    if (a > cast(ulong) long.max || b > cast(ulong) long.max
        || c > cast(ulong) long.max || d > cast(ulong) long.max)
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    long numerator;
    if (!multiplyChecked(cast(long) a, cast(long) d, numerator))
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    long denominator;
    if (!multiplyChecked(cast(long) b, cast(long) c, denominator))
        return ConversionResult!long.withoutValue(ConversionStatus.overflow);

    const bool negative =
        (FromUnit.Scale.numerator < 0) != (ToUnit.Scale.numerator < 0);
    if (negative)
        numerator = -numerator;

    return convertIntegralChecked(value, numerator, denominator);
}

@safe pure nothrow @nogc
bool finite(double value)
{
    return value == value
        && value <= double.max
        && value >= -double.max;
}

@safe pure nothrow @nogc
ConversionResult!double convertFloating(
    double value,
    long numerator,
    long denominator)
{
    assert(denominator > 0);

    if (!finite(value))
        return ConversionResult!double.withoutValue(ConversionStatus.nonFinite);

    const scaled = scaleBinary64(value, numerator, denominator);

    if (scaled.overflow)
        return ConversionResult!double.withoutValue(ConversionStatus.overflow);

    const status = rationalResultExactlyBinary64(
        value, numerator, denominator)
            ? ConversionStatus.exact
            : ConversionStatus.inexact;

    return ConversionResult!double.withValue(scaled.value, status);
}

@safe pure nothrow @nogc
ConversionResult!double convertFloatingUnits(FromUnit, ToUnit)(double value)
{
    ulong a = magnitude(FromUnit.Scale.numerator);
    ulong b = cast(ulong) FromUnit.Scale.denominator;
    ulong c = magnitude(ToUnit.Scale.numerator);
    ulong d = cast(ulong) ToUnit.Scale.denominator;

    auto divisor = gcd(a, c);
    a /= divisor;
    c /= divisor;

    divisor = gcd(d, b);
    d /= divisor;
    b /= divisor;

    if (a > cast(ulong) long.max || b > cast(ulong) long.max
        || c > cast(ulong) long.max || d > cast(ulong) long.max)
        return ConversionResult!double.withoutValue(ConversionStatus.overflow);

    long numerator;
    if (!multiplyChecked(cast(long) a, cast(long) d, numerator))
        return ConversionResult!double.withoutValue(ConversionStatus.overflow);

    long denominator;
    if (!multiplyChecked(cast(long) b, cast(long) c, denominator))
        return ConversionResult!double.withoutValue(ConversionStatus.overflow);

    const bool negative =
        (FromUnit.Scale.numerator < 0) != (ToUnit.Scale.numerator < 0);
    if (negative)
        numerator = -numerator;

    return convertFloating(value, numerator, denominator);
}

@safe pure nothrow @nogc
ExactResult!T exactResult(T)(ConversionResult!T result)
{
    final switch (result.status)
    {
        case ConversionStatus.exact:
            T value;
            if (result.tryValue(value))
                return ExactResult!T.success(value);

            // ConversionResult owns the invariant that exact implies a value.
            assert(false);
            return ExactResult!T.failed(ExactFailure.inexact);
        case ConversionStatus.inexact:
            return ExactResult!T.failed(ExactFailure.inexact);
        case ConversionStatus.overflow:
            return ExactResult!T.failed(ExactFailure.overflow);
        case ConversionStatus.nonFinite:
            return ExactResult!T.failed(ExactFailure.nonFinite);
    }
}

public:
@safe pure nothrow @nogc
auto checkedQuantity(Spec, Unit)(long value)
{
    static assert(isQuantitySpec!Spec,
        "checkedQuantity: Spec must define Dimension and a valid CanonicalUnit.");
    static assert(isUnit!Unit,
        "checkedQuantity: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "checkedQuantity: Spec and Unit must have the same Dimension.");

    const converted = convertIntegralUnitsChecked!(
        Unit, Spec.CanonicalUnit)(value);

    long canonical;
    if (!converted.tryValue(canonical))
        return ConversionResult!(Quantity!(Spec, long))
            .withoutValue(converted.status);

    return ConversionResult!(Quantity!(Spec, long)).withValue(
        Quantity!(Spec, long).fromCanonical(canonical),
        converted.status);
}

@safe pure nothrow @nogc
auto exactQuantity(Spec, Unit)(long value)
{
    return exactResult(value.checkedQuantity!(Spec, Unit));
}

@safe pure nothrow @nogc
auto roundedQuantity(Spec, Unit, RoundingMode mode)(long value)
{
    static assert(isQuantitySpec!Spec,
        "roundedQuantity: Spec must define Dimension and a valid CanonicalUnit.");
    static assert(isUnit!Unit,
        "roundedQuantity: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "roundedQuantity: Spec and Unit must have the same Dimension.");

    const converted = convertIntegralUnits!(Unit, Spec.CanonicalUnit)(value, mode);

    long canonical;
    if (!converted.tryValue(canonical))
        return ConversionResult!(Quantity!(Spec, long))
            .withoutValue(converted.status);

    return ConversionResult!(Quantity!(Spec, long)).withValue(
        Quantity!(Spec, long).fromCanonical(canonical),
        converted.status);
}

@safe pure nothrow @nogc
auto checkedIn(Unit, Spec)(Quantity!(Spec, long) value)
{
    static assert(isUnit!Unit,
        "checkedIn: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "checkedIn: Quantity Spec and Unit must have the same Dimension.");

    return convertIntegralUnitsChecked!(
        Spec.CanonicalUnit, Unit)(value.canonicalValue);
}

@safe pure nothrow @nogc
auto exactIn(Unit, Spec)(Quantity!(Spec, long) value)
{
    return exactResult(value.checkedIn!Unit);
}

@safe pure nothrow @nogc
auto roundedIn(Unit, RoundingMode mode, Spec)(Quantity!(Spec, long) value)
{
    static assert(isUnit!Unit,
        "roundedIn: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "roundedIn: Quantity Spec and Unit must have the same Dimension.");

    return convertIntegralUnits!(Spec.CanonicalUnit, Unit)(
        value.canonicalValue, mode);
}

@safe pure nothrow @nogc
auto checkedQuantity(Spec, Unit)(double value)
{
    static assert(isQuantitySpec!Spec,
        "checkedQuantity: Spec must define Dimension and a valid CanonicalUnit.");
    static assert(isUnit!Unit,
        "checkedQuantity: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "checkedQuantity: Spec and Unit must have the same Dimension.");

    const converted = convertFloatingUnits!(Unit, Spec.CanonicalUnit)(value);
    double canonical;
    if (!converted.tryValue(canonical))
        return ConversionResult!(Quantity!(Spec, double))
            .withoutValue(converted.status);

    return ConversionResult!(Quantity!(Spec, double)).withValue(
        Quantity!(Spec, double).fromCanonical(canonical),
        converted.status);
}

@safe pure nothrow @nogc
auto exactQuantity(Spec, Unit)(double value)
{
    return exactResult(value.checkedQuantity!(Spec, Unit));
}

@safe pure nothrow @nogc
auto checkedIn(Unit, Spec)(Quantity!(Spec, double) value)
{
    static assert(isUnit!Unit,
        "checkedIn: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "checkedIn: Quantity Spec and Unit must have the same Dimension.");

    return convertFloatingUnits!(Spec.CanonicalUnit, Unit)(
        value.canonicalValue);
}

@safe pure nothrow @nogc
auto exactIn(Unit, Spec)(Quantity!(Spec, double) value)
{
    return exactResult(value.checkedIn!Unit);
}

@safe unittest
{
    import quantities.quantity : quantity;
    import quantities.ratio : ExactRatio;

    struct LengthDimension {}

    struct Metre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 1);
    }

    struct Kilometre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1000, 1);
    }

    struct Centimetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 100);
    }

    struct Length
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;
    }

    enum km = 2L.exactQuantity!(Length, Kilometre);
    static assert(km.hasValue);
    static assert(({ Quantity!(Length, long) v; assert(km.tryValue(v)); return v.canonicalValue; }()) == 2000);

    enum back = ({ Quantity!(Length, long) v; assert(km.tryValue(v)); return v.exactIn!Kilometre; }());
    static assert(back.hasValue);
    static assert(({ long v; return back.tryValue(v) && v == 2; }()));

    enum checkedCm = 150L.checkedQuantity!(Length, Centimetre);
    static assert(checkedCm.status == ConversionStatus.inexact);
    static assert(!checkedCm.hasValue);

    enum cm = 150L.exactQuantity!(Length, Centimetre);
    static assert(!cm.hasValue);
    static assert(({ ExactFailure f; return cm.tryFailure(f) && f == ExactFailure.inexact; }()));

    enum rounded = 150L.roundedQuantity!(
        Length, Centimetre, RoundingMode.nearestTiesAway);
    static assert(rounded.status == ConversionStatus.inexact);
    static assert(({ Quantity!(Length, long) v; return rounded.tryValue(v) && v.canonicalValue == 2; }()));

    enum extraction = 1500L.quantity!(Length, Metre)
        .roundedIn!(Kilometre, RoundingMode.nearestTiesAway);
    static assert(extraction.status == ConversionStatus.inexact);
    static assert(({ long v; return extraction.tryValue(v) && v == 2; }()));

    enum minIdentity = long.min.exactQuantity!(Length, Metre);
    static assert(minIdentity.hasValue);
    static assert(({ Quantity!(Length, long) v; return minIdentity.tryValue(v) && v.canonicalValue == long.min; }()));

    enum negTowardZero = (-150L).roundedQuantity!(
        Length, Centimetre, RoundingMode.towardZero);
    static assert(negTowardZero.status == ConversionStatus.inexact);
    static assert(({ Quantity!(Length, long) v; return negTowardZero.tryValue(v) && v.canonicalValue == -1; }()));

    enum negFloor = (-150L).roundedQuantity!(
        Length, Centimetre, RoundingMode.floor);
    static assert(negFloor.status == ConversionStatus.inexact);
    static assert(({ Quantity!(Length, long) v; return negFloor.tryValue(v) && v.canonicalValue == -2; }()));

    enum negCeiling = (-150L).roundedQuantity!(
        Length, Centimetre, RoundingMode.ceiling);
    static assert(negCeiling.status == ConversionStatus.inexact);
    static assert(({ Quantity!(Length, long) v; return negCeiling.tryValue(v) && v.canonicalValue == -1; }()));

    enum negNearest = (-150L).roundedQuantity!(
        Length, Centimetre, RoundingMode.nearestTiesAway);
    static assert(negNearest.status == ConversionStatus.inexact);
    static assert(({ Quantity!(Length, long) v; return negNearest.tryValue(v) && v.canonicalValue == -2; }()));

    struct HugeNumeratorUnit
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(long.max, 2);
    }

    struct HugeDenominatorUnit
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, long.max);
    }

    enum cancelled = 2L.exactQuantity!(Length, HugeNumeratorUnit);
    static assert(cancelled.hasValue);
    static assert(({ Quantity!(Length, long) v; return cancelled.tryValue(v) && v.canonicalValue == long.max; }()));

    enum ratioOverflow = long.max.checkedQuantity!(
        Length, HugeNumeratorUnit);
    static assert(ratioOverflow.status == ConversionStatus.overflow);

    struct HalfMetreCanonical
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 2);
    }

    struct HalfMetreLength
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = HalfMetreCanonical;
    }

    struct MetreAgainstHalfCanonical
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 1);
    }

    enum nonUnitCanonicalScale = 1L.exactQuantity!(
        HalfMetreLength, MetreAgainstHalfCanonical);
    static assert(nonUnitCanonicalScale.hasValue);
    static assert(({ Quantity!(HalfMetreLength, long) v; return nonUnitCanonicalScale.tryValue(v) && v.canonicalValue == 2; }()));

    struct HalfMetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 2);
    }

    struct TenthMetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 10);
    }

    enum halfDouble = 3.0.exactQuantity!(Length, HalfMetre);
    static assert(halfDouble.hasValue);
    static assert(({ Quantity!(Length, double) v; return halfDouble.tryValue(v) && v.canonicalValue == 1.5; }()));

    enum tenthDouble = 1.0.exactQuantity!(Length, TenthMetre);
    static assert(!tenthDouble.hasValue);
    static assert(({ ExactFailure f; return tenthDouble.tryFailure(f) && f == ExactFailure.inexact; }()));

    enum checkedTenthDouble =
        1.0.checkedQuantity!(Length, TenthMetre);
    static assert(checkedTenthDouble.status == ConversionStatus.inexact);
    static assert(checkedTenthDouble.hasValue);

    // ADR 0007: arbitrary double CTFE does not promise represented-source
    // binary64 equality. Keep status/payload-availability coverage here;
    // exact represented-value checks belong to the runtime path.

    enum nanChecked =
        double.nan.checkedQuantity!(Length, Metre);
    static assert(nanChecked.status == ConversionStatus.nonFinite);

    enum infinityChecked =
        double.infinity.checkedQuantity!(Length, Metre);
    static assert(infinityChecked.status == ConversionStatus.nonFinite);

    enum overflowDouble =
        double.max.checkedQuantity!(Length, Kilometre);
    static assert(overflowDouble.status == ConversionStatus.overflow);

    struct TwoThirdsMetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(2, 3);
    }

    // Regression: the exact rational result is finite even though evaluating
    // double.max * 2 first would overflow.
    enum avoidableIntermediateOverflow =
        double.max.checkedQuantity!(Length, TwoThirdsMetre);
    static assert(avoidableIntermediateOverflow.status
        != ConversionStatus.overflow);
    static assert(({ Quantity!(Length, double) v; return avoidableIntermediateOverflow.tryValue(v)
        && v.canonicalValue <= double.max; }()));

    struct ThreeHalvesMetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(3, 2);
    }

    // Dual regression: scaling a minimum subnormal by 3/2 must not be
    // classified as overflow/non-finite. The represented result may round,
    // but intermediate ordering must not invent a different failure class.
    enum subnormalScaling =
        double.min_normal.checkedQuantity!(Length, ThreeHalvesMetre);
    static assert(subnormalScaling.status == ConversionStatus.exact
        || subnormalScaling.status == ConversionStatus.inexact);
    static assert(({ Quantity!(Length, double) v; return subnormalScaling.tryValue(v)
        && v.canonicalValue > 0.0; }()));
}
