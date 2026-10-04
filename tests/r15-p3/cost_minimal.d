module quantities.r15_p3_cost_minimal;

import quantities;

extern(C) long minimalQuantity(long value)
    @safe pure nothrow @nogc
{
    return value.quantity!(Length, Metre).canonicalValue;
}
