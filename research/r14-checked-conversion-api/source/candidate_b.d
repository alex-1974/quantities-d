module candidate_b;

import common;

enum ConversionPolicy
{
    checked,
    exact,
    rounded
}

struct ProbeQuantity(Spec, Rep)
{
    Rep value;
}

@safe pure nothrow @nogc
auto inUnit(Unit, ConversionPolicy policy, Spec, Rep)(ProbeQuantity!(Spec, Rep) value)
{
    return probeChecked(value.value);
}

@safe pure nothrow @nogc
auto quantity(Spec, Unit, ConversionPolicy policy, Rep)(Rep value)
{
    return ProbeQuantity!(Spec, Rep)(value);
}

@safe unittest
{
    enum q = 1.25.quantity!(Length, Kilometre, ConversionPolicy.checked);
    enum checked = q.inUnit!(Metre, ConversionPolicy.checked);
    enum exact = q.inUnit!(Metre, ConversionPolicy.exact);
    enum rounded = q.inUnit!(Metre, ConversionPolicy.rounded);
    static assert(checked.status == ConversionStatus.exact);
    static assert(exact.value == 1.25);
    static assert(rounded.value == 1.25);
}
