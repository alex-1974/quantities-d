module codegen;

struct Q(Rep)
{
    Rep value;
}

@safe pure nothrow @nogc
auto qAdd(int a, uint b)
{
    Q!int qa = Q!int(a);
    Q!uint qb = Q!uint(b);
    return Q!long(cast(long)qa.value + cast(long)qb.value);
}

@safe pure nothrow @nogc
auto qSub(uint a, uint b)
{
    Q!uint qa = Q!uint(a);
    Q!uint qb = Q!uint(b);
    return Q!long(cast(long)qa.value - cast(long)qb.value);
}

@safe pure nothrow @nogc
auto qMul(uint a, uint b)
{
    Q!uint qa = Q!uint(a);
    Q!uint qb = Q!uint(b);
    return Q!ulong(cast(ulong)qa.value * cast(ulong)qb.value);
}

@safe pure nothrow @nogc
auto qScale(int a, uint scalar)
{
    Q!int qa = Q!int(a);
    return Q!long(cast(long)qa.value * cast(long)scalar);
}

@safe pure nothrow @nogc
auto qScaleRight(uint scalar, int a)
{
    Q!int qa = Q!int(a);
    return Q!long(cast(long)scalar * cast(long)qa.value);
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long rawInlineAddIU(int a, uint b)
{
    return cast(long)a + cast(long)b;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long quantityInlineAddIU(int a, uint b)
{
    return qAdd(a, b).value;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long rawInlineSubUU(uint a, uint b)
{
    return cast(long)a - cast(long)b;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long quantityInlineSubUU(uint a, uint b)
{
    return qSub(a, b).value;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
ulong rawInlineMulUU(uint a, uint b)
{
    return cast(ulong)a * cast(ulong)b;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
ulong quantityInlineMulUU(uint a, uint b)
{
    return qMul(a, b).value;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long rawInlineScaleIU(int a, uint scalar)
{
    return cast(long)a * cast(long)scalar;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long quantityInlineScaleIU(int a, uint scalar)
{
    return qScale(a, scalar).value;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long rawInlineScaleRightUI(uint scalar, int a)
{
    return cast(long)scalar * cast(long)a;
}

extern(C) @safe pure nothrow @nogc pragma(inline, false)
long quantityInlineScaleRightUI(uint scalar, int a)
{
    return qScaleRight(scalar, a).value;
}
