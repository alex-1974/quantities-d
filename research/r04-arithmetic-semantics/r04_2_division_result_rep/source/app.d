module app;

import std.bigint : BigInt;
import std.stdio : writeln;
import std.traits : isIntegral, isSigned;

alias Types = AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong);

template AliasSeq(T...)
{
    alias AliasSeq = T;
}

struct Range
{
    BigInt min;
    BigInt max;
}

BigInt bmin(T)()
{
    return BigInt(T.min);
}

BigInt bmax(T)()
{
    return BigInt(T.max);
}

Range exactOracle(A, B)()
{
    BigInt amin = bmin!A;
    BigInt amax = bmax!A;

    BigInt qmin = amin;
    BigInt qmax = amax;

    static if (isSigned!B)
    {
        auto n1 = -amax;
        auto n2 = -amin;
        if (n1 < qmin) qmin = n1;
        if (n2 < qmin) qmin = n2;
        if (n1 > qmax) qmax = n1;
        if (n2 > qmax) qmax = n2;
    }

    return Range(qmin, qmax);
}

bool fits(T)(Range r)
{
    return r.min >= bmin!T && r.max <= bmax!T;
}

string oracleRep(A, B)()
{
    auto r = exactOracle!(A, B)();
    if (fits!byte(r)) return "byte";
    if (fits!ubyte(r)) return "ubyte";
    if (fits!short(r)) return "short";
    if (fits!ushort(r)) return "ushort";
    if (fits!int(r)) return "int";
    if (fits!uint(r)) return "uint";
    if (fits!long(r)) return "long";
    if (fits!ulong(r)) return "ulong";
    return "void";
}

template QuotientRep(A, B)
{
    static assert(isIntegral!A && isIntegral!B);

    // Candidate type-only rule:
    // unsigned divisor preserves dividend sign/range;
    // signed divisor also permits negating the complete dividend range.
    static if (!isSigned!B)
    {
        alias QuotientRep = A;
    }
    else static if (isSigned!A)
    {
        static if (A.sizeof < long.sizeof)
        {
            static if (A.sizeof == byte.sizeof)
                alias QuotientRep = short;
            else static if (A.sizeof == short.sizeof)
                alias QuotientRep = int;
            else
                alias QuotientRep = long;
        }
        else
            alias QuotientRep = void;
    }
    else
    {
        // Need both +A.max and -A.max.
        static if (A.sizeof < long.sizeof)
        {
            static if (A.sizeof == ubyte.sizeof)
                alias QuotientRep = short;
            else static if (A.sizeof == ushort.sizeof)
                alias QuotientRep = int;
            else
                alias QuotientRep = long;
        }
        else
            alias QuotientRep = void;
    }
}

string candidateName(A, B)()
{
    alias R = QuotientRep!(A, B);
    static if (is(R == void))
        return "void";
    else
        return R.stringof;
}

size_t mismatchCount(A, B)()
{
    auto candidate = candidateName!(A, B)();
    auto oracle = oracleRep!(A, B)();
    if (candidate != oracle)
    {
        auto r = exactOracle!(A, B)();
        writeln("MISMATCH ",
            A.stringof, "/", B.stringof,
            " candidate=", candidate,
            " oracle=", oracle,
            " range=[", r.min, ",", r.max, "]");
        return 1;
    }
    return 0;
}

void main()
{
    size_t pairs;
    size_t mismatches;

    static foreach (A; Types)
    {
        static foreach (B; Types)
        {
            ++pairs;
            mismatches += mismatchCount!(A, B)();
        }
    }

    writeln("checked pairs=", pairs, " mismatches=", mismatches);
    assert(mismatches == 0);
}
