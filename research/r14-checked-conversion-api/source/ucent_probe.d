module ucent_probe;

import core.int128 : UCent;

@safe pure nothrow @nogc
UCent mul128(ulong a, ulong b)
{
    return UCent(a) * UCent(b);
}

@safe pure nothrow @nogc
ulong low64(UCent value)
{
    return cast(ulong) value;
}

@safe unittest
{
    enum a = cast(ulong) long.max;
    enum b = cast(ulong) long.max - 2UL;
    enum product = mul128(a, b);

    enum q = product / UCent(b);
    enum r = product % UCent(b);
    static assert(q == UCent(a));
    static assert(r == UCent(0));

    enum sum = product + UCent(1);
    static assert(sum > product);
    static assert(low64(UCent(42)) == 42);

    const runtimeProduct = mul128(a, b);
    assert(runtimeProduct == product);
    assert(runtimeProduct / UCent(b) == UCent(a));
    assert(runtimeProduct % UCent(b) == UCent(0));
}
