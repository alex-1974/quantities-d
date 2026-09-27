module app;

import std.stdio : writeln;

template showType(alias expr)
{
    enum showType = typeof(expr).stringof;
}

void main()
{
    int neg = -1;
    uint oneU = 1U;

    auto addSignedUnsigned = neg + oneU;
    auto subSignedUnsigned = neg - oneU;
    auto mulSignedUnsigned = neg * oneU;

    writeln("-1 int + 1 uint -> ", typeof(addSignedUnsigned).stringof,
        " : ", addSignedUnsigned);
    writeln("-1 int - 1 uint -> ", typeof(subSignedUnsigned).stringof,
        " : ", subSignedUnsigned);
    writeln("-1 int * 1 uint -> ", typeof(mulSignedUnsigned).stringof,
        " : ", mulSignedUnsigned);

    byte b = 100;
    ubyte ub = 100;
    short s = 100;
    ushort us = 100;

    writeln("byte + byte -> ", typeof(b + b).stringof, " : ", b + b);
    writeln("ubyte + ubyte -> ", typeof(ub + ub).stringof, " : ", ub + ub);
    writeln("short + short -> ", typeof(s + s).stringof, " : ", s + s);
    writeln("ushort + ushort -> ", typeof(us + us).stringof, " : ", us + us);
    writeln("byte + ubyte -> ", typeof(b + ub).stringof, " : ", b + ub);
    writeln("short + ushort -> ", typeof(s + us).stringof, " : ", s + us);

    writeln("byte * byte -> ", typeof(b * b).stringof, " : ", b * b);
    writeln("short / short -> ", typeof(s / s).stringof, " : ", s / s);
}

enum ctfeNeg = cast(int)-1;
enum ctfeOneU = cast(uint)1;
enum ctfeSignedUnsignedAdd = ctfeNeg + ctfeOneU;
enum ctfeSignedUnsignedSub = ctfeNeg - ctfeOneU;
enum ctfeSignedUnsignedMul = ctfeNeg * ctfeOneU;

static assert(is(typeof(ctfeSignedUnsignedAdd) == uint));
static assert(is(typeof(ctfeSignedUnsignedSub) == uint));
static assert(is(typeof(ctfeSignedUnsignedMul) == uint));
