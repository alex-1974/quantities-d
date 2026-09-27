module binary64_bits_probe;

import std.bitmanip : nativeToLittleEndian;

@safe pure nothrow @nogc
ulong bitsOf(double value)
{
    union U
    {
        double d;
        ulong u;
    }

    U v;
    v.d = value;
    return v.u;
}

@safe unittest
{
    const runtimeBits = bitsOf(0.1);
    assert(runtimeBits == 0x3FB999999999999AUL);

    // Runtime sanity for nearby values.
    assert(bitsOf(0.5) == 0x3FE0000000000000UL);
    assert(bitsOf(1.0) == 0x3FF0000000000000UL);
}
