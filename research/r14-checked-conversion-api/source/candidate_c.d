module candidate_c;

import checked_kernel : convertIntegral;
import common;

struct ProbeQuantity(Spec, Rep)
{
    Rep value;
}

@safe pure nothrow @nogc
auto checkedIn(Unit, Spec)(ProbeQuantity!(Spec, long) value)
{
    static if (is(Unit == Metre))
        return convertIntegral(value.value, 1, 1);
    else
        return convertIntegral(value.value, 1, 1000);
}

@safe pure nothrow @nogc
auto exactIn(Unit, Spec)(ProbeQuantity!(Spec, long) value)
{
    const result = value.checkedIn!Unit;
    return result;
}

@safe pure nothrow @nogc
auto roundedIn(Unit, RoundingMode mode, Spec)(ProbeQuantity!(Spec, long) value)
{
    static if (is(Unit == Metre))
        return convertIntegral(value.value, 1, 1, mode);
    else
        return convertIntegral(value.value, 1, 1000, mode);
}

@safe pure nothrow @nogc
auto checkedQuantity(Spec, Unit)(long value)
{
    static if (is(Unit == Metre))
        return ConversionResult!(ProbeQuantity!(Spec, long))(
            ProbeQuantity!(Spec, long)(value),
            ConversionStatus.exact);
    else
    {
        const converted = convertIntegral(value, 1000, 1);
        return ConversionResult!(ProbeQuantity!(Spec, long))(
            ProbeQuantity!(Spec, long)(converted.value),
            converted.status);
    }
}

@safe unittest
{
    enum source = 1500L.checkedQuantity!(Length, Metre);
    static assert(source.status == ConversionStatus.exact);

    enum q = source.value;

    enum checked = q.checkedIn!Kilometre;
    static assert(checked.status == ConversionStatus.inexact);
    static assert(checked.value == 1);

    enum towardZero = q.roundedIn!(Kilometre, RoundingMode.towardZero);
    static assert(towardZero.status == ConversionStatus.inexact);
    static assert(towardZero.value == 1);

    enum floorValue = (-1500L).checkedQuantity!(Length, Metre).value
        .roundedIn!(Kilometre, RoundingMode.floor);
    static assert(floorValue.status == ConversionStatus.inexact);
    static assert(floorValue.value == -2);

    enum exactKm = 2L.checkedQuantity!(Length, Kilometre);
    static assert(exactKm.status == ConversionStatus.exact);
    static assert(exactKm.value.value == 2000);

    enum roundTrip = exactKm.value.exactIn!Kilometre;
    static assert(roundTrip.status == ConversionStatus.exact);
    static assert(roundTrip.value == 2);
}
