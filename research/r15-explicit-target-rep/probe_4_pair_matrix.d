module r15_probe_4_pair_matrix;

import std.stdio : writeln;
import std.traits : isIntegral;

enum PairClass
{
    totalExact,
    valueDependentExact,
    checkedRounded,
    unsupportedFormat
}

private enum bool FloatingContainsAll(S, T) =
    T.mant_dig >= S.mant_dig &&
    T.min_exp <= S.min_exp &&
    T.max_exp >= S.max_exp;

private enum int IntegralValueBits(T) =
    T.sizeof * 8 - (is(T == byte) || is(T == short) || is(T == int) || is(T == long) ? 1 : 0);

private enum bool FloatingContainsIntegralDomain(I, F) =
    isIntegral!I &&
    IntegralValueBits!I <= F.mant_dig;

private string name(PairClass c)
{
    final switch (c)
    {
        case PairClass.totalExact:
            return "totalExact";
        case PairClass.valueDependentExact:
            return "valueDependentExact";
        case PairClass.checkedRounded:
            return "checkedRounded";
        case PairClass.unsupportedFormat:
            return "unsupportedFormat";
    }
}

private PairClass classify(S, T)()
{
    static if (isIntegral!S && isIntegral!T)
    {
        static if (S.sizeof < T.sizeof)
            return PairClass.totalExact;
        else static if (S.sizeof == T.sizeof && is(S == T))
            return PairClass.totalExact;
        else
            return PairClass.valueDependentExact;
    }
    else static if (isIntegral!S && is(T == float) || isIntegral!S && is(T == double) || isIntegral!S && is(T == real))
    {
        static if (FloatingContainsIntegralDomain!(S, T))
            return PairClass.totalExact;
        else
            return PairClass.valueDependentExact;
    }
    else static if ((is(S == float) || is(S == double) || is(S == real)) &&
                    (is(T == float) || is(T == double) || is(T == real)))
    {
        static if (FloatingContainsAll!(S, T))
            return PairClass.totalExact;
        else
            return PairClass.valueDependentExact;
    }
    else static if ((is(S == float) || is(S == double) || is(S == real)) && isIntegral!T)
    {
        return PairClass.checkedRounded;
    }
    else
    {
        return PairClass.unsupportedFormat;
    }
}

private void row(S, T)(string s, string t)
{
    writeln(s, " -> ", t, ": ", name(classify!(S,T)()));
}

void main()
{
    writeln("=== IDENTITY-SCALE REPRESENTATION PAIR MATRIX ===");

    row!(long, float)("long", "float");
    row!(long, double)("long", "double");
    row!(long, real)("long", "real");

    row!(ulong, float)("ulong", "float");
    row!(ulong, double)("ulong", "double");
    row!(ulong, real)("ulong", "real");

    row!(float, double)("float", "double");
    row!(float, real)("float", "real");
    row!(double, float)("double", "float");
    row!(double, real)("double", "real");
    row!(real, float)("real", "float");
    row!(real, double)("real", "double");

    row!(float, long)("float", "long");
    row!(double, long)("double", "long");
    row!(real, long)("real", "long");

    static assert(classify!(float,double) == PairClass.totalExact);
    static assert(classify!(double,float) == PairClass.valueDependentExact);
    static assert(classify!(long,double) == PairClass.valueDependentExact);
    static assert(classify!(float,long) == PairClass.checkedRounded);

    static if (
        real.mant_dig >= double.mant_dig &&
        real.min_exp <= double.min_exp &&
        real.max_exp >= double.max_exp)
    {
        static assert(classify!(double,real) == PairClass.totalExact);
    }

    writeln();
    writeln("Interpretation:");
    writeln("  totalExact          = representation alone cannot lose information");
    writeln("  valueDependentExact = individual values may be exact; checked/exact required");
    writeln("  checkedRounded      = integer target needs exact/rounding policy");
    writeln();
    writeln("R15 Probe 4 PASS: pair classes separated from unit-rescale policy");
}
