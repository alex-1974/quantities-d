module codegen;

struct Length {}

struct Q(Spec, Rep)
{
    Rep value;

    auto opBinary(string op, R2)(Q!(Spec, R2) rhs) const
        @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        alias RR = typeof(mixin("value " ~ op ~ " rhs.value"));
        return Q!(Spec, RR)(mixin("value " ~ op ~ " rhs.value"));
    }

    auto opBinary(string op, S)(S scalar) const
        @safe pure nothrow @nogc
        if ((op == "*" || op == "/") && is(S : float))
    {
        alias RR = typeof(mixin("value " ~ op ~ " scalar"));
        return Q!(Spec, RR)(mixin("value " ~ op ~ " scalar"));
    }
}

extern(C):

pragma(inline, false)
double rawAddFD(float a, double b) @safe pure nothrow @nogc
{
    return a + b;
}

pragma(inline, false)
double quantityAddFD(float a, double b) @safe pure nothrow @nogc
{
    auto qa = Q!(Length, float)(a);
    auto qb = Q!(Length, double)(b);
    return (qa + qb).value;
}

pragma(inline, false)
double rawScaleFD(float a, double scalar) @safe pure nothrow @nogc
{
    return a * scalar;
}

pragma(inline, false)
double quantityScaleFD(float a, double scalar) @safe pure nothrow @nogc
{
    auto q = Q!(Length, float)(a);
    return (q * scalar).value;
}

pragma(inline, false)
double rawDivDF(double a, float scalar) @safe pure nothrow @nogc
{
    return a / scalar;
}

pragma(inline, false)
double quantityDivDF(double a, float scalar) @safe pure nothrow @nogc
{
    auto q = Q!(Length, double)(a);
    return (q / scalar).value;
}
