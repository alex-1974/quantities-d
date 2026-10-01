module conversion_as_bits;
import core.stdc.string : memcpy;
import std.traits : Unqual;
// Test protocol helpers. No production internals imported by consumers.
enum qualifiedReal = (real.mant_dig == 64 && real.min_exp == -16381 && real.max_exp == 16384) ||
    (real.mant_dig == 53 && real.min_exp == -1021 && real.max_exp == 1024);
ulong storedBits(T)(T value) @safe pure nothrow @nogc
    if (is(Unqual!T == float) || is(Unqual!T == double))
{
    static if (is(Unqual!T == float))
    {
        uint raw;
        () @trusted { memcpy(&raw,&value,uint.sizeof); }();
        return raw;
    }
    else
    {
        ulong raw;
        () @trusted { memcpy(&raw,&value,ulong.sizeof); }();
        return raw;
    }
}
T fromBits(T)(ulong raw) @safe pure nothrow @nogc if (is(T == float) || is(T == double))
{
    T value;
    static if (is(T == float))
    {
        const uint bits = cast(uint)raw;
        () @trusted { memcpy(&value,&bits,uint.sizeof); }();
    }
    else () @trusted { memcpy(&value,&raw,ulong.sizeof); }();
    return value;
}
