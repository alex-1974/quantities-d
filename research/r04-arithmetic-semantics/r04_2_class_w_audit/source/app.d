module app;

import std.bigint : BigInt;
import std.meta : AliasSeq;
import std.stdio : writeln;
import std.traits : isIntegral, isSigned;

alias Types = AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong);

template Bits(T) { enum Bits = T.sizeof * 8; }
template ValueBits(T) { enum ValueBits = Bits!T - (isSigned!T ? 1 : 0); }

template SignedForBits(size_t n)
{
    static if (n <= 7) alias SignedForBits = byte;
    else static if (n <= 15) alias SignedForBits = short;
    else static if (n <= 31) alias SignedForBits = int;
    else static if (n <= 63) alias SignedForBits = long;
    else alias SignedForBits = void;
}

template UnsignedForBits(size_t n)
{
    static if (n <= 8) alias UnsignedForBits = ubyte;
    else static if (n <= 16) alias UnsignedForBits = ushort;
    else static if (n <= 32) alias UnsignedForBits = uint;
    else static if (n <= 64) alias UnsignedForBits = ulong;
    else alias UnsignedForBits = void;
}

// Current R04.2.5 candidate.
template CandidateAdd(A,B)
{
    static if (Bits!A > 32 || Bits!B > 32) alias CandidateAdd = void;
    else {
        enum signedResult = isSigned!A || isSigned!B;
        enum n = (ValueBits!A > ValueBits!B ? ValueBits!A : ValueBits!B) + 1;
        static if (signedResult) alias CandidateAdd = SignedForBits!n;
        else alias CandidateAdd = UnsignedForBits!n;
    }
}

template CandidateSub(A,B)
{
    alias CandidateSub = CandidateAdd!(A,B);
}

template CandidateMul(A,B)
{
    static if (Bits!A > 32 || Bits!B > 32) alias CandidateMul = void;
    else {
        enum signedResult = isSigned!A || isSigned!B;
        enum n = ValueBits!A + ValueBits!B;
        static if (signedResult) alias CandidateMul = SignedForBits!n;
        else alias CandidateMul = UnsignedForBits!n;
    }
}

BigInt lo(T)() { return BigInt(T.min); }
BigInt hi(T)() { return BigInt(T.max); }

string smallest(BigInt a, BigInt b)
{
    if (a >= lo!byte && b <= hi!byte) return "byte";
    if (a >= lo!ubyte && b <= hi!ubyte) return "ubyte";
    if (a >= lo!short && b <= hi!short) return "short";
    if (a >= lo!ushort && b <= hi!ushort) return "ushort";
    if (a >= lo!int && b <= hi!int) return "int";
    if (a >= lo!uint && b <= hi!uint) return "uint";
    if (a >= lo!long && b <= hi!long) return "long";
    if (a >= lo!ulong && b <= hi!ulong) return "ulong";
    return "void";
}

string exactAdd(A,B)() { return smallest(lo!A + lo!B, hi!A + hi!B); }
string exactSub(A,B)() { return smallest(lo!A - hi!B, hi!A - lo!B); }

string exactMul(A,B)()
{
    BigInt[4] x = [lo!A*lo!B, lo!A*hi!B, hi!A*lo!B, hi!A*hi!B];
    BigInt mn=x[0], mx=x[0];
    foreach(v; x[1..$]) { if(v<mn) mn=v; if(v>mx) mx=v; }
    return smallest(mn,mx);
}

string typeName(T)() { return T.stringof; }

void compare(A,B)()
{
    alias CA=CandidateAdd!(A,B);
    alias CS=CandidateSub!(A,B);
    alias CM=CandidateMul!(A,B);
    auto ea=exactAdd!(A,B)();
    auto es=exactSub!(A,B)();
    auto em=exactMul!(A,B)();

    if (typeName!CA != ea)
        writeln("ADD ", A.stringof,"/",B.stringof,
                " candidate=",typeName!CA," exact=",ea);
    if (typeName!CS != es)
        writeln("SUB ", A.stringof,"/",B.stringof,
                " candidate=",typeName!CS," exact=",es);
    if (typeName!CM != em)
        writeln("MUL ", A.stringof,"/",B.stringof,
                " candidate=",typeName!CM," exact=",em);
}

void main()
{
    size_t pairs;
    static foreach(A; Types)
        static foreach(B; Types) {
            compare!(A,B)();
            ++pairs;
        }
    writeln("checked pairs=", pairs, " operations=", pairs*3);
}
