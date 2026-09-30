module r15_probe_1_surface_matrix;

import std.stdio : writeln;
import quantities;

private void printProps(T)(string name)
{
    writeln(
        name,
        ": sizeof=", T.sizeof,
        " mant_dig=", T.mant_dig,
        " min_exp=", T.min_exp,
        " max_exp=", T.max_exp);
}

private enum bool FloatContainsAllIntegral(I, F) =
    is(I == byte) || is(I == ubyte) ||
    is(I == short) || is(I == ushort)
        ? (I.sizeof * 8 - (is(I == byte) || is(I == short) ? 1 : 0)) <= F.mant_dig
        : false;

void main()
{
    writeln("=== REPRESENTATION PROPERTIES ===");
    printProps!float("float");
    printProps!double("double");
    printProps!real("real");

    writeln();
    writeln("=== CURRENT PUBLIC CONSTRUCTION SURFACE ===");

    static assert(__traits(compiles,
        1L.checkedQuantity!(Length, Metre)));
    static assert(__traits(compiles,
        1.0.checkedQuantity!(Length, Metre)));

    enum floatConstructionCompiles =
        __traits(compiles,
            1.0f.checkedQuantity!(Length, Metre));

    enum realConstructionCompiles =
        __traits(compiles,
            1.0L.checkedQuantity!(Length, Metre));

    writeln("float.checkedQuantity compiles: ", floatConstructionCompiles);
    writeln("real.checkedQuantity compiles:  ", realConstructionCompiles);

    static if (floatConstructionCompiles)
    {
        alias FloatConstruction =
            typeof(1.0f.checkedQuantity!(Length, Metre));

        static assert(is(
            FloatConstruction ==
            ConversionResult!(Quantity!(Length, double))));

        writeln(
            "float source currently resolves to: "
            "ConversionResult!(Quantity!(Length, double))");
    }

    static if (realConstructionCompiles)
    {
        alias RealConstruction =
            typeof(1.0L.checkedQuantity!(Length, Metre));

        writeln("real source current result type: ", RealConstruction.stringof);
    }

    writeln();
    writeln("=== CURRENT PUBLIC EXTRACTION SURFACE ===");

    alias QLong = Quantity!(Length, long);
    alias QFloat = Quantity!(Length, float);
    alias QDouble = Quantity!(Length, double);
    alias QReal = Quantity!(Length, real);

    enum longExtraction =
        __traits(compiles,
            QLong.init.checkedIn!Metre);
    enum floatExtraction =
        __traits(compiles,
            QFloat.init.checkedIn!Metre);
    enum doubleExtraction =
        __traits(compiles,
            QDouble.init.checkedIn!Metre);
    enum realExtraction =
        __traits(compiles,
            QReal.init.checkedIn!Metre);

    writeln("Quantity<long>.checkedIn:   ", longExtraction);
    writeln("Quantity<float>.checkedIn:  ", floatExtraction);
    writeln("Quantity<double>.checkedIn: ", doubleExtraction);
    writeln("Quantity<real>.checkedIn:   ", realExtraction);

    writeln();
    writeln("=== FORMAT-INCLUSION FACTS ===");

    static assert(float.mant_dig == 24);
    static assert(double.mant_dig == 53);

    enum floatIntoDoubleTotal =
        double.mant_dig >= float.mant_dig &&
        double.min_exp <= float.min_exp &&
        double.max_exp >= float.max_exp;

    enum doubleIntoRealTotal =
        real.mant_dig >= double.mant_dig &&
        real.min_exp <= double.min_exp &&
        real.max_exp >= double.max_exp;

    enum realIntoDoubleTotal =
        double.mant_dig >= real.mant_dig &&
        double.min_exp <= real.min_exp &&
        double.max_exp >= real.max_exp;

    writeln("float -> double total exact: ", floatIntoDoubleTotal);
    writeln("double -> real total exact on this target: ", doubleIntoRealTotal);
    writeln("real -> double total exact on this target: ", realIntoDoubleTotal);

    writeln();
    writeln("=== COMPLETE INTEGER-DOMAIN FACTS ===");
    writeln("byte  -> float total exact: ", FloatContainsAllIntegral!(byte, float));
    writeln("ubyte -> float total exact: ", FloatContainsAllIntegral!(ubyte, float));
    writeln("short -> float total exact: ", FloatContainsAllIntegral!(short, float));
    writeln("ushort-> float total exact: ", FloatContainsAllIntegral!(ushort, float));

    // These wider integer domains are known not to fit binary32 completely.
    writeln("int   -> float total exact: false");
    writeln("uint  -> float total exact: false");

    // binary64 contains every 32-bit integer exactly but not every 64-bit integer.
    writeln("int   -> double total exact: true");
    writeln("uint  -> double total exact: true");
    writeln("long  -> double total exact: false");
    writeln("ulong -> double total exact: false");

    writeln();
    writeln("R15 Probe 1 PASS: current surface and representation matrix recorded");
}
