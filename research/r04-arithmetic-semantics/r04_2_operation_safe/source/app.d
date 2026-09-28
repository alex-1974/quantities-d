module app;

import std.bigint : BigInt;
import std.stdio : writeln;
import std.traits : isSigned;

BigInt lo(T)()
{
    return BigInt(T.min);
}

BigInt hi(T)()
{
    return BigInt(T.max);
}

bool contains(T)(BigInt a, BigInt b)
{
    return a >= lo!T && b <= hi!T;
}

string smallest(BigInt a, BigInt b)
{
    if (contains!byte(a,b)) return "byte";
    if (contains!ubyte(a,b)) return "ubyte";
    if (contains!short(a,b)) return "short";
    if (contains!ushort(a,b)) return "ushort";
    if (contains!int(a,b)) return "int";
    if (contains!uint(a,b)) return "uint";
    if (contains!long(a,b)) return "long";
    if (contains!ulong(a,b)) return "ulong";
    return "none";
}

string addRep(A,B)()
{
    return smallest(lo!A + lo!B, hi!A + hi!B);
}

string subRep(A,B)()
{
    return smallest(lo!A - hi!B, hi!A - lo!B);
}

string mulRep(A,B)()
{
    BigInt[4] x = [
        lo!A * lo!B,
        lo!A * hi!B,
        hi!A * lo!B,
        hi!A * hi!B
    ];
    BigInt mn = x[0], mx = x[0];
    foreach (v; x[1 .. $])
    {
        if (v < mn) mn = v;
        if (v > mx) mx = v;
    }
    return smallest(mn, mx);
}

void row(A,B)(string name)
{
    writeln(name,
        " | +:", addRep!(A,B)(),
        " -:", subRep!(A,B)(),
        " *:", mulRep!(A,B)());
}

void main()
{
    writeln("A/B | smallest operation-safe built-in Rep");
    row!(byte,byte)("byte/byte");
    row!(ubyte,ubyte)("ubyte/ubyte");
    row!(byte,ubyte)("byte/ubyte");
    row!(short,short)("short/short");
    row!(ushort,ushort)("ushort/ushort");
    row!(short,ushort)("short/ushort");
    row!(int,int)("int/int");
    row!(uint,uint)("uint/uint");
    row!(int,uint)("int/uint");
    row!(int,long)("int/long");
    row!(uint,long)("uint/long");
    row!(long,long)("long/long");
    row!(uint,ulong)("uint/ulong");
    row!(int,ulong)("int/ulong");
    row!(long,ulong)("long/ulong");
    row!(ulong,ulong)("ulong/ulong");
}
