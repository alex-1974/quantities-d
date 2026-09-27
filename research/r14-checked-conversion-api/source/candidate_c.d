module candidate_c;

import checked_kernel : convertIntegralComposed;
import common;
import exact_result : ExactFailure, ExactResult;

struct ProbeQuantity(Spec, Rep)
{
    Rep value;
}

private:
@safe pure nothrow @nogc
ConversionResult!long checkedScale(FromUnit, ToUnit)(long value)
{
    // value * FromScale / ToScale. The research Units use normalized positive
    // denominators, so the composed ratio stays explicit at this boundary.
    // Production algebra will cross-cancel before composing ratios.
    return convertIntegralComposed(
        value,
        FromUnit.UnitScale.numerator,
        FromUnit.UnitScale.denominator,
        ToUnit.UnitScale.numerator,
        ToUnit.UnitScale.denominator);
}

@safe pure nothrow @nogc
ConversionResult!long roundedScale(FromUnit, ToUnit)(
    long value,
    RoundingMode mode)
{
    return convertIntegralComposed(
        value,
        FromUnit.UnitScale.numerator,
        FromUnit.UnitScale.denominator,
        ToUnit.UnitScale.numerator,
        ToUnit.UnitScale.denominator,
        mode);
}

@safe pure nothrow @nogc
ExactResult!long exactFromChecked(ConversionResult!long result)
{
    final switch (result.status)
    {
        case ConversionStatus.exact:
            return ExactResult!long.success(result.value);
        case ConversionStatus.inexact:
            return ExactResult!long.failed(ExactFailure.inexact);
        case ConversionStatus.overflow:
            return ExactResult!long.failed(ExactFailure.overflow);
    }
}

public:
@safe pure nothrow @nogc
auto checkedIn(Unit, Spec)(ProbeQuantity!(Spec, long) value)
{
    return checkedScale!(Spec.CanonicalUnit, Unit)(value.value);
}

@safe pure nothrow @nogc
auto exactIn(Unit, Spec)(ProbeQuantity!(Spec, long) value)
{
    return exactFromChecked(value.checkedIn!Unit);
}

@safe pure nothrow @nogc
auto roundedIn(Unit, RoundingMode mode, Spec)(ProbeQuantity!(Spec, long) value)
{
    return roundedScale!(Spec.CanonicalUnit, Unit)(value.value, mode);
}

@safe pure nothrow @nogc
auto checkedQuantity(Spec, Unit)(long value)
{
    const converted = checkedScale!(Unit, Spec.CanonicalUnit)(value);
    return ConversionResult!(ProbeQuantity!(Spec, long))(
        ProbeQuantity!(Spec, long)(converted.value),
        converted.status);
}

@safe pure nothrow @nogc
auto exactQuantity(Spec, Unit)(long value)
{
    const converted = checkedScale!(Unit, Spec.CanonicalUnit)(value);
    final switch (converted.status)
    {
        case ConversionStatus.exact:
            return ExactResult!(ProbeQuantity!(Spec, long)).success(
                ProbeQuantity!(Spec, long)(converted.value));
        case ConversionStatus.inexact:
            return ExactResult!(ProbeQuantity!(Spec, long)).failed(
                ExactFailure.inexact);
        case ConversionStatus.overflow:
            return ExactResult!(ProbeQuantity!(Spec, long)).failed(
                ExactFailure.overflow);
    }
}

@safe pure nothrow @nogc
auto roundedQuantity(Spec, Unit, RoundingMode mode)(long value)
{
    const converted = roundedScale!(Unit, Spec.CanonicalUnit)(value, mode);
    return ConversionResult!(ProbeQuantity!(Spec, long))(
        ProbeQuantity!(Spec, long)(converted.value),
        converted.status);
}

@safe unittest
{
    enum km = 2L.exactQuantity!(Length, Kilometre);
    static assert(km.hasValue);
    static assert(km.value.value == 2000);

    enum back = km.value.exactIn!Kilometre;
    static assert(back.hasValue);
    static assert(back.value == 2);

    enum cm = 150L.exactQuantity!(Length, Centimetre);
    static assert(!cm.hasValue);
    static assert(cm.failure == ExactFailure.inexact);

    enum checkedCm = 150L.checkedQuantity!(Length, Centimetre);
    static assert(checkedCm.status == ConversionStatus.inexact);

    enum roundedCm = 150L.roundedQuantity!(
        Length, Centimetre, RoundingMode.nearestTiesAway);
    static assert(roundedCm.status == ConversionStatus.inexact);
    static assert(roundedCm.value.value == 2);

    enum metres = 1500L.exactQuantity!(Length, Metre);
    static assert(metres.hasValue);

    enum checkedKm = metres.value.checkedIn!Kilometre;
    static assert(checkedKm.status == ConversionStatus.inexact);
    static assert(checkedKm.value == 1);

    enum roundedKm = metres.value.roundedIn!(
        Kilometre, RoundingMode.nearestTiesAway);
    static assert(roundedKm.status == ConversionStatus.inexact);
    static assert(roundedKm.value == 2);
}
