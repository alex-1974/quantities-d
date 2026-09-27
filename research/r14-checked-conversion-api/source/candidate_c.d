module candidate_c;

import common;

struct ProbeQuantity(Spec, Rep)
{
    Rep value;
}

@safe pure nothrow @nogc
auto checkedIn(Unit, Spec, Rep)(ProbeQuantity!(Spec, Rep) value)
{
    return probeChecked(value.value);
}

@safe pure nothrow @nogc
auto exactIn(Unit, Spec, Rep)(ProbeQuantity!(Spec, Rep) value)
{
    const result = value.checkedIn!Unit;
    return result;
}

@safe pure nothrow @nogc
auto roundedIn(Unit, RoundingMode mode, Spec, Rep)(ProbeQuantity!(Spec, Rep) value)
{
    const result = value.checkedIn!Unit;
    return result;
}

@safe pure nothrow @nogc
auto checkedQuantity(Spec, Unit, Rep)(Rep value)
{
    return ProbeQuantity!(Spec, Rep)(value);
}

@safe unittest
{
    enum q = 1.25.checkedQuantity!(Length, Kilometre);
    enum checked = q.checkedIn!Metre;
    enum exact = q.exactIn!Metre;
    enum rounded = q.roundedIn!(Metre, RoundingMode.floor);
    static assert(checked.status == ConversionStatus.exact);
    static assert(exact.value == 1.25);
    static assert(rounded.value == 1.25);
}
