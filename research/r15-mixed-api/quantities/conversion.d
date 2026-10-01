module quantities.conversion;

import quantities.binary64_scale :
    rationalResultWithinBinary64Range, scaleBinary64;
import quantities.floating_exact : rationalResultExactlyBinary64;
import quantities.quantity : Quantity;
import quantities.traits : isQuantitySpec, isUnit;
import std.traits : Unqual;

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
    // Probe 14 hardening: private fields alone do not suppress D struct literals.
    @disable this(bool, T, ConversionStatus);
    bool hasValue_;
    T value_;
    ConversionStatus status_ = ConversionStatus.inexact;

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

public:
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
    @disable this(bool, T, ExactFailure);
    bool hasValue_;
    T value_;
    ExactFailure failure_ = ExactFailure.inexact;

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

    if (!rationalResultWithinBinary64Range(value, numerator, denominator))
        return ConversionResult!double.withoutValue(ConversionStatus.overflow);

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

            // Defensive fallback for an impossible internal state. Result
            // construction is internal, but keep release behavior independent
            // of assertions if an invariant is ever violated internally.
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

// Guard the currently implemented construction source-Rep contract.
//
// Without these exact-match templates, D may implicitly convert unsupported
// source types before overload resolution reaches the long/double kernels
// (for example ulong -> long or real -> double). That would let information be
// lost before quantities-d can report conversion status.
@safe pure nothrow @nogc
auto checkedQuantity(Spec, Unit, Source)(Source value)
    if (!is(Unqual!Source == long) && !is(Unqual!Source == double))
{
    static assert(false,
        "checkedQuantity: source Rep is not supported by the current conversion contract.");
}

@safe pure nothrow @nogc
auto exactQuantity(Spec, Unit, Source)(Source value)
    if (!is(Unqual!Source == long) && !is(Unqual!Source == double))
{
    static assert(false,
        "exactQuantity: source Rep is not supported by the current conversion contract.");
}

@safe pure nothrow @nogc
auto roundedQuantity(Spec, Unit, RoundingMode mode, Source)(Source value)
    if (!is(Unqual!Source == long))
{
    static assert(false,
        "roundedQuantity: source Rep is not supported by the current conversion contract.");
}

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
    // Default initialization must itself be a valid public state.
    ConversionResult!long conversionDefault;
    assert(!conversionDefault.hasValue);
    assert(conversionDefault.status == ConversionStatus.inexact);
    long conversionValue;
    assert(!conversionDefault.tryValue(conversionValue));

    ExactResult!long exactDefault;
    assert(!exactDefault.hasValue);
    long exactValue;
    assert(!exactDefault.tryValue(exactValue));
    ExactFailure exactFailure;
    assert(exactDefault.tryFailure(exactFailure));
    assert(exactFailure == ExactFailure.inexact);
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

    // ADR 0007: represented-source floating conversion is a runtime contract.
    const halfDouble = 3.0.exactQuantity!(Length, HalfMetre);
    assert(halfDouble.hasValue);
    Quantity!(Length, double) halfValue;
    assert(halfDouble.tryValue(halfValue));
    assert(halfValue.canonicalValue == 1.5);

    const tenthDouble = 1.0.exactQuantity!(Length, TenthMetre);
    assert(!tenthDouble.hasValue);
    ExactFailure tenthFailure;
    assert(tenthDouble.tryFailure(tenthFailure));
    assert(tenthFailure == ExactFailure.inexact);

    const checkedTenthDouble =
        1.0.checkedQuantity!(Length, TenthMetre);
    assert(checkedTenthDouble.status == ConversionStatus.inexact);
    assert(checkedTenthDouble.hasValue);
    Quantity!(Length, double) checkedTenthValue;
    assert(checkedTenthDouble.tryValue(checkedTenthValue));
    assert(checkedTenthValue.canonicalValue == 0.1);

    enum nanChecked =
        double.nan.checkedQuantity!(Length, Metre);
    static assert(nanChecked.status == ConversionStatus.nonFinite);

    enum infinityChecked =
        double.infinity.checkedQuantity!(Length, Metre);
    static assert(infinityChecked.status == ConversionStatus.nonFinite);

    const overflowDouble =
        double.max.checkedQuantity!(Length, Kilometre);
    assert(overflowDouble.status == ConversionStatus.overflow);

    struct TwoThirdsMetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(2, 3);
    }

    // Regression: the exact rational result is finite even though evaluating
    // double.max * 2 first would overflow.
    const avoidableIntermediateOverflow =
        double.max.checkedQuantity!(Length, TwoThirdsMetre);
    assert(avoidableIntermediateOverflow.status
        != ConversionStatus.overflow);
    Quantity!(Length, double) finiteScaledValue;
    assert(avoidableIntermediateOverflow.tryValue(finiteScaledValue));
    assert(finiteScaledValue.canonicalValue <= double.max);

    struct ThreeHalvesMetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(3, 2);
    }

    // Dual regression: scaling a minimum subnormal by 3/2 must not be
    // classified as overflow/non-finite. The represented result may round,
    // but intermediate ordering must not invent a different failure class.
    const subnormalScaling =
        double.min_normal.checkedQuantity!(Length, ThreeHalvesMetre);
    assert(subnormalScaling.status == ConversionStatus.exact
        || subnormalScaling.status == ConversionStatus.inexact);
    Quantity!(Length, double) subnormalValue;
    assert(subnormalScaling.tryValue(subnormalValue));
    assert(subnormalValue.canonicalValue > 0.0);

    // Adversarial runtime matrix for represented-source binary64 semantics.
    const negativeTenth =
        (-1.0).checkedQuantity!(Length, TenthMetre);
    assert(negativeTenth.status == ConversionStatus.inexact);
    Quantity!(Length, double) negativeTenthValue;
    assert(negativeTenth.tryValue(negativeTenthValue));
    assert(negativeTenthValue.canonicalValue == -0.1);

    const exactHalf =
        1.0.checkedQuantity!(Length, HalfMetre);
    assert(exactHalf.status == ConversionStatus.exact);
    Quantity!(Length, double) exactHalfValue;
    assert(exactHalf.tryValue(exactHalfValue));
    assert(exactHalfValue.canonicalValue == 0.5);

    const negativeExactHalf =
        (-1.0).checkedQuantity!(Length, HalfMetre);
    assert(negativeExactHalf.status == ConversionStatus.exact);
    Quantity!(Length, double) negativeExactHalfValue;
    assert(negativeExactHalf.tryValue(negativeExactHalfValue));
    assert(negativeExactHalfValue.canonicalValue == -0.5);

    const negativeAvoidableOverflow =
        (-double.max).checkedQuantity!(Length, TwoThirdsMetre);
    assert(negativeAvoidableOverflow.status
        != ConversionStatus.overflow);
    Quantity!(Length, double) negativeFiniteScaledValue;
    assert(negativeAvoidableOverflow.tryValue(negativeFiniteScaledValue));
    assert(negativeFiniteScaledValue.canonicalValue >= -double.max);

    const negativeOverflow =
        (-double.max).checkedQuantity!(Length, Kilometre);
    assert(negativeOverflow.status == ConversionStatus.overflow);
    assert(!negativeOverflow.hasValue);

    const minSubnormal = double.min_normal * double.epsilon;

    const subnormalTieToEven =
        minSubnormal.checkedQuantity!(Length, ThreeHalvesMetre);
    assert(subnormalTieToEven.status == ConversionStatus.inexact);
    Quantity!(Length, double) subnormalTieValue;
    assert(subnormalTieToEven.tryValue(subnormalTieValue));
    assert(subnormalTieValue.canonicalValue == minSubnormal * 2.0);

    const negativeSubnormalTieToEven =
        (-minSubnormal).checkedQuantity!(Length, ThreeHalvesMetre);
    assert(negativeSubnormalTieToEven.status == ConversionStatus.inexact);
    Quantity!(Length, double) negativeSubnormalTieValue;
    assert(negativeSubnormalTieToEven.tryValue(negativeSubnormalTieValue));
    assert(negativeSubnormalTieValue.canonicalValue
        == -(minSubnormal * 2.0));

    const subnormalUnderflow =
        minSubnormal.checkedQuantity!(Length, HalfMetre);
    assert(subnormalUnderflow.status == ConversionStatus.inexact);
    Quantity!(Length, double) underflowValue;
    assert(subnormalUnderflow.tryValue(underflowValue));
    assert(underflowValue.canonicalValue == 0.0);

    const negativeSubnormalUnderflow =
        (-minSubnormal).checkedQuantity!(Length, HalfMetre);
    assert(negativeSubnormalUnderflow.status == ConversionStatus.inexact);
    Quantity!(Length, double) negativeUnderflowValue;
    assert(negativeSubnormalUnderflow.tryValue(negativeUnderflowValue));
    assert(negativeUnderflowValue.canonicalValue == -0.0);

    const negativeInfinityChecked =
        (-double.infinity).checkedQuantity!(Length, Metre);
    assert(negativeInfinityChecked.status == ConversionStatus.nonFinite);
    assert(!negativeInfinityChecked.hasValue);
}

@safe unittest
{
    import quantities : Length, LengthDimension, Metre, DerivedUnit, ExactRatio;

    enum long d = 1L << 62;
    alias AboveMetre = DerivedUnit!(LengthDimension, ExactRatio!(d + 1, d));
    alias BelowMetre = DerivedUnit!(LengthDimension, ExactRatio!(d, d + 1));

    foreach (source; [double.max, -double.max])
    {
        // Even an out-of-range result that rounds to finite double.max
        // must report overflow, through construction and extraction alike.
        const constructed = source.checkedQuantity!(Length, AboveMetre);
        assert(constructed.status == ConversionStatus.overflow);
        assert(!constructed.hasValue);
        Quantity!(Length, double) quantityOutput;
        assert(!constructed.tryValue(quantityOutput));

        const exactConstructed = source.exactQuantity!(Length, AboveMetre);
        ExactFailure failure;
        assert(!exactConstructed.hasValue);
        assert(exactConstructed.tryFailure(failure));
        assert(failure == ExactFailure.overflow);

        const q = Quantity!(Length, double).fromCanonical(source);
        const extracted = q.checkedIn!BelowMetre;
        assert(extracted.status == ConversionStatus.overflow);
        assert(!extracted.hasValue);
        double scalarOutput;
        assert(!extracted.tryValue(scalarOutput));

        const exactExtracted = q.exactIn!BelowMetre;
        assert(!exactExtracted.hasValue);
        assert(exactExtracted.tryFailure(failure));
        assert(failure == ExactFailure.overflow);

        // The exact boundary and values strictly inside remain valid.
        const boundary = source.checkedQuantity!(Length, Metre);
        assert(boundary.status == ConversionStatus.exact);
        assert(boundary.tryValue(quantityOutput));
        assert(quantityOutput.canonicalValue == source);

        const inside = source.checkedQuantity!(Length, BelowMetre);
        assert(inside.status == ConversionStatus.inexact);
        assert(inside.tryValue(quantityOutput));
        assert(quantityOutput.canonicalValue == source);
    }
}


// R15 Probe 14 extension. All preceding production code is copied verbatim.
private:
import r15_floating_integral_kernel : convertFloatingLong, qualifiedReal;
import r15_composed_kernel : IntegralRoundingMode;
import r15_rescale_kernel : Status;

template r15FloatingSource(S)
{
    enum r15FloatingSource = is(Unqual!S == float) || is(Unqual!S == double) ||
        (is(Unqual!S == real) && qualifiedReal);
}

template r15Units(Spec, Unit)
{
    static assert(isQuantitySpec!Spec, "R15 requires a valid Spec.");
    static assert(isUnit!Unit, "R15 requires a valid Unit.");
    static assert(is(Spec.Dimension == Unit.Dimension), "R15 dimension mismatch.");
    static assert(Unit.Scale.numerator != 0 && Spec.CanonicalUnit.Scale.numerator != 0,
        "R15 Unit scales must be nonzero.");
    static assert(is(typeof(Unit.Scale.numerator) == long) &&
        is(typeof(Unit.Scale.denominator) == long) &&
        is(typeof(Spec.CanonicalUnit.Scale.numerator) == long) &&
        is(typeof(Spec.CanonicalUnit.Scale.denominator) == long),
        "R15 requires signed-long exact Scale metadata.");
    enum r15Units = true;
}

ConversionResult!long r15Convert(From, To, Source)(Source value, bool rounded,
    RoundingMode mode) @safe pure nothrow @nogc
{
    const converted = convertFloatingLong(value,
        From.Scale.numerator, From.Scale.denominator,
        To.Scale.numerator, To.Scale.denominator, rounded,
        cast(IntegralRoundingMode)mode);
    // Map names explicitly: research enum layout is not an integration contract.
    final switch (converted.status)
    {
        case Status.exact:
            return ConversionResult!long.withValue(converted.value, ConversionStatus.exact);
        case Status.inexact:
            return converted.hasValue
                ? ConversionResult!long.withValue(converted.value, ConversionStatus.inexact)
                : ConversionResult!long.withoutValue(ConversionStatus.inexact);
        case Status.overflow:
            return ConversionResult!long.withoutValue(ConversionStatus.overflow);
        case Status.nonFinite:
            return ConversionResult!long.withoutValue(ConversionStatus.nonFinite);
    }
}

auto r15Construct(Spec, Unit, Source)(Source value, bool rounded, RoundingMode mode)
    @safe pure nothrow @nogc
{
    static assert(r15Units!(Spec, Unit));
    const converted = r15Convert!(Unit, Spec.CanonicalUnit)(value, rounded, mode);
    long canonical;
    if (!converted.tryValue(canonical))
        return ConversionResult!(Quantity!(Spec, long)).withoutValue(converted.status);
    return ConversionResult!(Quantity!(Spec, long)).withValue(
        Quantity!(Spec, long).fromCanonical(canonical), converted.status);
}

public:
// Candidate names and TargetRep placement only; target scope is deliberately long.
auto checkedQuantityAs(Spec, Unit, TargetRep, Source)(Source value)
    @safe pure nothrow @nogc if (r15FloatingSource!Source)
{
    static assert(is(TargetRep == long), "R15 Probe 14 target must be long.");
    return r15Construct!(Spec, Unit)(value, false, RoundingMode.towardZero);
}

auto exactQuantityAs(Spec, Unit, TargetRep, Source)(Source value)
    @safe pure nothrow @nogc if (r15FloatingSource!Source)
{
    return exactResult(value.checkedQuantityAs!(Spec, Unit, TargetRep));
}

auto roundedQuantityAs(Spec, Unit, TargetRep, RoundingMode mode, Source)(Source value)
    @safe pure nothrow @nogc if (r15FloatingSource!Source)
{
    static assert(is(TargetRep == long), "R15 Probe 14 target must be long.");
    static assert(mode == RoundingMode.towardZero || mode == RoundingMode.floor ||
        mode == RoundingMode.ceiling || mode == RoundingMode.nearestTiesAway,
        "R15 requires a supported rounding mode.");
    return r15Construct!(Spec, Unit)(value, true, mode);
}

auto checkedInAs(Unit, TargetRep, Spec, Source)(const(Quantity!(Spec, Source)) value)
    @safe pure nothrow @nogc if (r15FloatingSource!Source)
{
    static assert(is(TargetRep == long), "R15 Probe 14 target must be long.");
    static assert(r15Units!(Spec, Unit));
    return r15Convert!(Spec.CanonicalUnit, Unit)(value.canonicalValue, false,
        RoundingMode.towardZero);
}

auto exactInAs(Unit, TargetRep, Spec, Source)(const(Quantity!(Spec, Source)) value)
    @safe pure nothrow @nogc if (r15FloatingSource!Source)
{
    return exactResult(value.checkedInAs!(Unit, TargetRep));
}

auto roundedInAs(Unit, TargetRep, RoundingMode mode, Spec, Source)(
    const(Quantity!(Spec, Source)) value)
    @safe pure nothrow @nogc if (r15FloatingSource!Source)
{
    static assert(is(TargetRep == long), "R15 Probe 14 target must be long.");
    static assert(mode == RoundingMode.towardZero || mode == RoundingMode.floor ||
        mode == RoundingMode.ceiling || mode == RoundingMode.nearestTiesAway,
        "R15 requires a supported rounding mode.");
    static assert(r15Units!(Spec, Unit));
    return r15Convert!(Spec.CanonicalUnit, Unit)(value.canonicalValue, true, mode);
}
