module app;

import core.stdc.string : memcpy;
import std.math : isNaN, isInfinity, signbit;
import std.stdio : writefln, writeln;

ulong bitsOf(double value) @trusted pure nothrow @nogc
{
    ulong bits;
    memcpy(&bits, &value, value.sizeof);
    return bits;
}

uint bitsOf(float value) @trusted pure nothrow @nogc
{
    uint bits;
    memcpy(&bits, &value, value.sizeof);
    return bits;
}

void show(T)(string label, T value)
{
    static if (is(T == float))
        writefln("%-32s type=%-6s value=%s bits=%08x nan=%s inf=%s sign=%s",
            label, T.stringof, value, bitsOf(value), isNaN(value),
            isInfinity(value), signbit(value));
    else static if (is(T == double))
        writefln("%-32s type=%-6s value=%s bits=%016x nan=%s inf=%s sign=%s",
            label, T.stringof, value, bitsOf(value), isNaN(value),
            isInfinity(value), signbit(value));
}

void main()
{
    float f = 1.5f;
    double d = 2.25;

    show("float + float", f + f);
    show("float + double", f + d);
    show("double + float", d + f);
    show("double + double", d + d);

    show("+0f + -0f", 0.0f + -0.0f);
    show("-0f + -0f", -0.0f + -0.0f);
    show("+0.0 + -0.0", 0.0 + -0.0);
    show("-0.0 + -0.0", -0.0 + -0.0);

    float fInf = float.infinity;
    double dInf = double.infinity;
    float fNaN = float.nan;
    double dNaN = double.nan;

    show("+inf + finite float", fInf + f);
    show("-inf + finite double", -dInf + d);
    show("+inf + -inf", dInf + -dInf);
    show("NaN + finite float", fNaN + f);
    show("NaN * finite double", dNaN * d);

    show("float.max * 2f", float.max * 2.0f);
    show("double.max * 2.0", double.max * 2.0);

    show("float / +0f", f / 0.0f);
    show("float / -0f", f / -0.0f);
    show("double / +0.0", d / 0.0);
    show("double / -0.0", d / -0.0);

    show("+0f / +0f", 0.0f / 0.0f);
    show("-0.0 / +0.0", -0.0 / 0.0);

    float sub = float.min_normal / 2.0f;
    double dsub = double.min_normal / 2.0;
    show("float subnormal", sub);
    show("double subnormal", dsub);
}

enum ctfeFF = 1.5f + 2.0f;
enum ctfeFD = 1.5f + 2.0;
enum ctfeDD = 1.5 + 2.0;
enum ctfeNegZero = -0.0 + -0.0;
enum ctfeWide = double.max * 2.0;

static assert(is(typeof(ctfeFF) == float));
static assert(is(typeof(ctfeFD) == double));
static assert(is(typeof(ctfeDD) == double));
static assert(ctfeFF == 3.5f);
static assert(ctfeFD == 3.5);
static assert(ctfeDD == 3.5);
static assert(signbit(ctfeNegZero));
static assert(ctfeWide > double.max);
