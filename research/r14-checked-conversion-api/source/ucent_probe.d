module ucent_probe;

@safe pure nothrow @nogc
ucent mul128(ulong a, ulong b)
{
    return cast(ucent) a * cast(ucent) b;
}

@safe pure nothrow @nogc
ulong high64(ucent value)
{
    return cast(ulong)(value >> 64);
}

@safe unittest
{
    enum a = cast(ulong) long.max;
    enum b = cast(ulong) long.max - 2UL;
    enum product = mul128(a, b);

    static assert(product > cast(ucent) ulong.max);
    static assert(high64(product) != 0);

    enum q = product / cast(ucent) b;
    enum r = product % cast(ucent) b;
    static assert(q == a);
    static assert(r == 0);

    const runtimeProduct = mul128(a, b);
    assert(runtimeProduct == product);
    assert(high64(runtimeProduct) == high64(product));
}
