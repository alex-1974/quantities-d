module app;

import std.stdio : writeln;

template NativeResult(A, B, string op)
{
    alias NativeResult = typeof(mixin("A.init " ~ op ~ " B.init"));
}

void row(A, B)(string names)
{
    alias Add = NativeResult!(A, B, "+");
    alias Sub = NativeResult!(A, B, "-");
    alias Mul = NativeResult!(A, B, "*");
    writeln(names,
        " | +:", Add.stringof,
        " -:", Sub.stringof,
        " *:", Mul.stringof);
}

void main()
{
    writeln("A/B | native + - * ResultRep");
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
