module codegen;

struct Length {}

struct Q(Rep)
{
    Rep value;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long rawAddIU(int a, uint b)
{
    return cast(long)a + cast(long)b;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long quantityAddIU(Q!int a, Q!uint b)
{
    return cast(long)a.value + cast(long)b.value;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long rawSubUU(uint a, uint b)
{
    return cast(long)a - cast(long)b;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long quantitySubUU(Q!uint a, Q!uint b)
{
    return cast(long)a.value - cast(long)b.value;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
ulong rawMulUU(uint a, uint b)
{
    return cast(ulong)a * cast(ulong)b;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
ulong quantityMulUU(Q!uint a, Q!uint b)
{
    return cast(ulong)a.value * cast(ulong)b.value;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long rawScaleIU(int a, uint scalar)
{
    return cast(long)a * cast(long)scalar;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long quantityScaleIU(Q!int a, uint scalar)
{
    return cast(long)a.value * cast(long)scalar;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long rawScaleRightUI(uint scalar, int a)
{
    return cast(long)scalar * cast(long)a;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long quantityScaleRightUI(uint scalar, Q!int a)
{
    return cast(long)scalar * cast(long)a.value;
}
