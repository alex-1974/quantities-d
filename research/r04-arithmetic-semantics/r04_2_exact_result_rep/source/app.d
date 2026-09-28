module app;

import std.bigint : BigInt;
import std.meta : AliasSeq;
import std.stdio : writeln;
import std.traits : isSigned;

alias Types = AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong);

enum bits(T) = T.sizeof * 8;
enum posBits(T) = bits!T - (isSigned!T ? 1 : 0);
enum negPow(T) = isSigned!T ? bits!T - 1 : 0;

// Range-shape descriptor. maxBits means an upper bound <= 2^maxBits-1.
// minPow means a lower bound >= -2^minPow. Zero means non-negative.
struct Shape { size_t minPow; size_t maxBits; }

// ceil(log2((2^a-1)+(2^b-1)+1)) for positive maxima.
enum sumMaxBits(size_t a, size_t b) =
    a == b ? a + 1 : (a > b ? a : b);

// For multiplication of non-negative maxima:
// (2^a-1)(2^b-1) < 2^(a+b), and for nonzero widths needs a+b bits
// except 1-bit edge cases are still safely handled by selection below.
enum productMaxBits(size_t a, size_t b) = a + b;

template AddShape(A, B)
{
    // Exact range-shape rules without materializing endpoints.
    //
    // S(a)+S(b):
    //   negative magnitude = 2^(a-1)+2^(b-1)
    //   positive maximum   = (2^(a-1)-1)+(2^(b-1)-1)
    //
    // S(s)+U(u):
    //   negative magnitude = 2^(s-1)
    //   positive maximum   = (2^(s-1)-1)+(2^u-1)
    //
    // U(a)+U(b):
    //   non-negative only.
    static if (isSigned!A && isSigned!B)
        enum AddShape = Shape(
            negPow!A == negPow!B
                ? negPow!A + 1
                : (negPow!A > negPow!B ? negPow!A + 1 : negPow!B + 1),
            sumMaxBits!(posBits!A, posBits!B)
        );
    else static if (!isSigned!A && !isSigned!B)
        enum AddShape = Shape(
            0,
            sumMaxBits!(posBits!A, posBits!B)
        );
    else static if (isSigned!A)
        enum AddShape = Shape(
            negPow!A,
            sumMaxBits!(posBits!A, posBits!B)
        );
    else
        enum AddShape = Shape(
            negPow!B,
            sumMaxBits!(posBits!A, posBits!B)
        );
}

template SubShape(A, B)
{
    // min = Amin - Bmax
    // max = Amax - Bmin
    //
    // Keep the four signedness cases explicit because subtraction is
    // asymmetric.
    static if (isSigned!A && isSigned!B)
        enum SubShape = Shape(
            // 2^(a-1) + (2^(b-1)-1): needs max exponent + 1
            negPow!A >= posBits!B ? negPow!A + 1 : posBits!B + 1,
            // (2^(a-1)-1) + 2^(b-1)
            posBits!A >= negPow!B ? posBits!A + 1 : negPow!B + 1
        );
    else static if (!isSigned!A && !isSigned!B)
        enum SubShape = Shape(
            posBits!B,
            posBits!A
        );
    else static if (isSigned!A) // S - U
        enum SubShape = Shape(
            // 2^(a-1) + (2^u-1)
            negPow!A >= posBits!B ? negPow!A + 1 : posBits!B + 1,
            posBits!A
        );
    else // U - S
        enum SubShape = Shape(
            posBits!B,
            // (2^u-1) + 2^(b-1)
            posBits!A >= negPow!B ? posBits!A + 1 : negPow!B + 1
        );
}

template MulShape(A,B)
{
    static if (!isSigned!A && !isSigned!B)
        enum MulShape = Shape(0, productMaxBits!(posBits!A,posBits!B));
    else static if (isSigned!A && isSigned!B)
        enum MulShape = Shape(
            negPow!A + posBits!B,
            negPow!A + negPow!B + 1
        );
    else static if (isSigned!A)
        enum MulShape = Shape(
            negPow!A + posBits!B,
            posBits!A + posBits!B
        );
    else
        enum MulShape = Shape(
            posBits!A + negPow!B,
            posBits!A + posBits!B
        );
}

bool fitsShape(T)(Shape s)
{
    static if (isSigned!T)
        return s.minPow <= bits!T - 1 && s.maxBits <= bits!T - 1;
    else
        return s.minPow == 0 && s.maxBits <= bits!T;
}

string select(Shape s)
{
    if (fitsShape!byte(s)) return "byte";
    if (fitsShape!ubyte(s)) return "ubyte";
    if (fitsShape!short(s)) return "short";
    if (fitsShape!ushort(s)) return "ushort";
    if (fitsShape!int(s)) return "int";
    if (fitsShape!uint(s)) return "uint";
    if (fitsShape!long(s)) return "long";
    if (fitsShape!ulong(s)) return "ulong";
    return "void";
}

BigInt lo(T)(){ return BigInt(T.min); }
BigInt hi(T)(){ return BigInt(T.max); }
string exact(BigInt a, BigInt b)
{
    if(a>=lo!byte && b<=hi!byte)return "byte";
    if(a>=lo!ubyte && b<=hi!ubyte)return "ubyte";
    if(a>=lo!short && b<=hi!short)return "short";
    if(a>=lo!ushort && b<=hi!ushort)return "ushort";
    if(a>=lo!int && b<=hi!int)return "int";
    if(a>=lo!uint && b<=hi!uint)return "uint";
    if(a>=lo!long && b<=hi!long)return "long";
    if(a>=lo!ulong && b<=hi!ulong)return "ulong";
    return "void";
}

string exactAdd(A,B)(){return exact(lo!A+lo!B,hi!A+hi!B);}
string exactSub(A,B)(){return exact(lo!A-hi!B,hi!A-lo!B);}
string exactMul(A,B)(){
    BigInt[4] x=[lo!A*lo!B,lo!A*hi!B,hi!A*lo!B,hi!A*hi!B];
    BigInt mn=x[0],mx=x[0];
    foreach(v;x[1..$]){if(v<mn)mn=v;if(v>mx)mx=v;}
    return exact(mn,mx);
}

void check(A,B)()
{
    auto ca=select(AddShape!(A,B));
    auto cs=select(SubShape!(A,B));
    auto cm=select(MulShape!(A,B));
    auto ea=exactAdd!(A,B)(), es=exactSub!(A,B)(), em=exactMul!(A,B)();
    if(ca!=ea) writeln("ADD ",A.stringof,"/",B.stringof," candidate=",ca," exact=",ea);
    if(cs!=es) writeln("SUB ",A.stringof,"/",B.stringof," candidate=",cs," exact=",es);
    if(cm!=em) writeln("MUL ",A.stringof,"/",B.stringof," candidate=",cm," exact=",em);
}

size_t mismatchCount(A, B)()
{
    size_t mismatches;
    auto ca = select(AddShape!(A, B)), ea = exactAdd!(A, B)();
    auto cs = select(SubShape!(A, B)), es = exactSub!(A, B)();
    auto cm = select(MulShape!(A, B)), em = exactMul!(A, B)();

    if (ca != ea) {
        writeln("ADD ", A.stringof, "/", B.stringof,
                " candidate=", ca, " exact=", ea);
        ++mismatches;
    }
    if (cs != es) {
        writeln("SUB ", A.stringof, "/", B.stringof,
                " candidate=", cs, " exact=", es);
        ++mismatches;
    }
    if (cm != em) {
        writeln("MUL ", A.stringof, "/", B.stringof,
                " candidate=", cm, " exact=", em);
        ++mismatches;
    }
    return mismatches;
}

void main()
{
    size_t pairs, mismatches;
    static foreach (A; Types)
        static foreach (B; Types) {
            mismatches += mismatchCount!(A, B)();
            ++pairs;
        }

    writeln("checked pairs=", pairs,
            " operations=", pairs * 3,
            " mismatches=", mismatches);
}
