module app;

import std.math : isNaN, isInfinity, signbit;
import std.stdio : writeln;

struct LengthDimension {}
struct Metre
{
    alias Dimension = LengthDimension;
}
struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct Q(Spec, Rep)
{
    private Rep canonical_;

    this(Rep value) @safe pure nothrow @nogc
    {
        canonical_ = value;
    }

    Rep canonicalValue() const @safe pure nothrow @nogc
    {
        return canonical_;
    }

    auto opBinary(string op, R2)(Q!(Spec, R2) rhs) const
        @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        alias ResultRep = typeof(mixin("canonical_ " ~ op ~ " rhs.canonicalValue"));
        return Q!(Spec, ResultRep)(
            mixin("canonical_ " ~ op ~ " rhs.canonicalValue"));
    }

    auto opBinary(string op, Scalar)(Scalar scalar) const
        @safe pure nothrow @nogc
        if ((op == "*" || op == "/") && is(Scalar : float))
    {
        alias ResultRep = typeof(mixin("canonical_ " ~ op ~ " scalar"));
        return Q!(Spec, ResultRep)(mixin("canonical_ " ~ op ~ " scalar"));
    }

    auto opBinaryRight(string op, Scalar)(Scalar scalar) const
        @safe pure nothrow @nogc
        if (op == "*" && is(Scalar : float))
    {
        alias ResultRep = typeof(mixin("scalar * canonical_"));
        return Q!(Spec, ResultRep)(scalar * canonical_);
    }
}

@safe pure nothrow @nogc
auto attributeProbe()
{
    Q!(Length, float) a = Q!(Length, float)(1.5f);
    Q!(Length, double) b = Q!(Length, double)(2.25);
    auto sum = a + b;
    auto scaled = sum * 2.0;
    auto divided = scaled / 2.0;
    return divided;
}

enum ctfe = attributeProbe();
static assert(is(typeof(ctfe) == Q!(Length, double)));
static assert(ctfe.canonicalValue == 3.75);

void main()
{
    auto f = Q!(Length, float)(1.5f);
    auto d = Q!(Length, double)(2.25);

    auto ff = f + f;
    auto fd = f + d;
    auto df = d + f;
    auto dd = d + d;

    static assert(is(typeof(ff) == Q!(Length, float)));
    static assert(is(typeof(fd) == Q!(Length, double)));
    static assert(is(typeof(df) == Q!(Length, double)));
    static assert(is(typeof(dd) == Q!(Length, double)));

    writeln("ff: ", ff.canonicalValue, " rep=", typeof(ff.canonicalValue).stringof);
    writeln("fd: ", fd.canonicalValue, " rep=", typeof(fd.canonicalValue).stringof);
    writeln("df: ", df.canonicalValue, " rep=", typeof(df.canonicalValue).stringof);
    writeln("dd: ", dd.canonicalValue, " rep=", typeof(dd.canonicalValue).stringof);

    auto scaled = f * 2.0;
    auto reverse = 2.0 * f;
    auto divided = d / 2.0f;

    static assert(is(typeof(scaled) == Q!(Length, double)));
    static assert(is(typeof(reverse) == Q!(Length, double)));
    static assert(is(typeof(divided) == Q!(Length, double)));

    writeln("scaled: ", scaled.canonicalValue);
    writeln("reverse: ", reverse.canonicalValue);
    writeln("divided: ", divided.canonicalValue);

    auto inf = Q!(Length, double)(double.infinity);
    auto ninf = Q!(Length, double)(-double.infinity);
    auto nanResult = inf + ninf;
    writeln("inf+ninf nan=", isNaN(nanResult.canonicalValue));

    auto negZero = Q!(Length, double)(-0.0) + Q!(Length, double)(-0.0);
    writeln("-0+-0 sign=", signbit(negZero.canonicalValue));

    auto overflow = Q!(Length, double)(double.max) * 2.0;
    writeln("max*2 inf=", isInfinity(overflow.canonicalValue));
}
