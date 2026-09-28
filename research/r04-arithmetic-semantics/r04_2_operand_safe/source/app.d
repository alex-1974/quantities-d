module app;

import std.stdio : writeln;
import std.traits : isIntegral, isSigned;

template FitsAll(From, To)
{
    static assert(isIntegral!From && isIntegral!To);

    static if (isSigned!From)
    {
        static if (isSigned!To)
            enum FitsAll = From.min >= To.min && From.max <= To.max;
        else
            enum FitsAll = false;
    }
    else
    {
        static if (isSigned!To)
            enum FitsAll = From.max <= To.max;
        else
            enum FitsAll = From.max <= To.max;
    }
}

template FitsBoth(A, B, T)
{
    enum FitsBoth = FitsAll!(A, T) && FitsAll!(B, T);
}

template OperandSafeCommon(A, B)
{
    static assert(isIntegral!A && isIntegral!B);

    static if (FitsBoth!(A, B, byte))
        alias OperandSafeCommon = byte;
    else static if (FitsBoth!(A, B, ubyte))
        alias OperandSafeCommon = ubyte;
    else static if (FitsBoth!(A, B, short))
        alias OperandSafeCommon = short;
    else static if (FitsBoth!(A, B, ushort))
        alias OperandSafeCommon = ushort;
    else static if (FitsBoth!(A, B, int))
        alias OperandSafeCommon = int;
    else static if (FitsBoth!(A, B, uint))
        alias OperandSafeCommon = uint;
    else static if (FitsBoth!(A, B, long))
        alias OperandSafeCommon = long;
    else static if (FitsBoth!(A, B, ulong))
        alias OperandSafeCommon = ulong;
    else
        alias OperandSafeCommon = void;
}

void row(A, B)(string name)
{
    alias R = OperandSafeCommon!(A, B);
    writeln(name, " -> ", R.stringof);
    static assert(is(R == OperandSafeCommon!(B, A)));
}

static assert(is(OperandSafeCommon!(byte, byte) == byte));
static assert(is(OperandSafeCommon!(ubyte, ubyte) == ubyte));
static assert(is(OperandSafeCommon!(byte, ubyte) == short));
static assert(is(OperandSafeCommon!(short, ushort) == int));
static assert(is(OperandSafeCommon!(int, uint) == long));
static assert(is(OperandSafeCommon!(uint, long) == long));
static assert(is(OperandSafeCommon!(long, ulong) == void));
static assert(is(OperandSafeCommon!(int, ulong) == void));
static assert(is(OperandSafeCommon!(uint, ulong) == ulong));

void main()
{
    row!(byte, byte)("byte/byte");
    row!(ubyte, ubyte)("ubyte/ubyte");
    row!(byte, ubyte)("byte/ubyte");
    row!(short, short)("short/short");
    row!(ushort, ushort)("ushort/ushort");
    row!(short, ushort)("short/ushort");
    row!(int, int)("int/int");
    row!(uint, uint)("uint/uint");
    row!(int, uint)("int/uint");
    row!(long, long)("long/long");
    row!(ulong, ulong)("ulong/ulong");
    row!(long, ulong)("long/ulong");
    row!(int, long)("int/long");
    row!(uint, long)("uint/long");
    row!(int, ulong)("int/ulong");
    row!(uint, ulong)("uint/ulong");
}
