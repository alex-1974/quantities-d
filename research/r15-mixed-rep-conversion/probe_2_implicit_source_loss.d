module r15_probe_2_implicit_source_loss;

import core.stdc.string : memcpy;
import std.stdio : writeln;
import quantities;

private void report(T)(string name, T value)
{
    enum compiles =
        __traits(compiles,
            value.checkedQuantity!(Length, Metre));

    writeln(name, " compiles: ", compiles);

    static if (compiles)
    {
        alias Result =
            typeof(value.checkedQuantity!(Length, Metre));
        writeln("  result type: ", Result.stringof);
    }
}

void main()
{
    writeln("=== CURRENT SOURCE-TYPE ACCEPTANCE ===");

    report!byte("byte", byte(1));
    report!ubyte("ubyte", ubyte(1));
    report!short("short", short(1));
    report!ushort("ushort", ushort(1));
    report!int("int", int(1));
    report!uint("uint", uint(1));
    report!long("long", long(1));
    report!ulong("ulong", ulong(1));
    report!float("float", float(1));
    report!double("double", double(1));
    report!real("real", real(1));

    writeln();
    writeln("=== ULONG PRE-CALL NARROWING WITNESS ===");

    auto unsignedConverted =
        ulong.max.checkedQuantity!(Length, Metre);

    static assert(is(
        typeof(unsignedConverted)
        == ConversionResult!(Quantity!(Length, long))));

    assert(unsignedConverted.hasValue);
    assert(unsignedConverted.status == ConversionStatus.exact);

    Quantity!(Length, long) signedQuantity;
    assert(unsignedConverted.tryValue(signedQuantity));

    writeln("ulong.max source: ", ulong.max);
    writeln("stored signed canonical: ", signedQuantity.canonicalValue);
    writeln("checkedQuantity status: ", unsignedConverted.status);

    assert(
        cast(ulong)signedQuantity.canonicalValue
        != ulong.max
        || signedQuantity.canonicalValue < 0);

    writeln();
    writeln("=== REAL PRE-CALL NARROWING WITNESS ===");

    // real.max is finite in the represented source format on this target but
    // exceeds binary64 range. The current overload narrows it to double before
    // quantities-d can classify the represented real source.
    static assert(real.max > cast(real)double.max);

    const real representedSource = real.max;
    assert(representedSource == representedSource);
    assert(representedSource != real.infinity);

    // Force the overload's effective argument representation into an actual
    // binary64 object, then compare it back in real precision.
    const double narrowedSource =
        cast(double)representedSource;

    ulong storedBits;
    () @trusted {
        memcpy(&storedBits, &narrowedSource, double.sizeof);
    }();

    double storedDouble;
    () @trusted {
        memcpy(&storedDouble, &storedBits, double.sizeof);
    }();

    assert(cast(real)storedDouble != representedSource);

    auto realConverted =
        representedSource.checkedQuantity!(Length, Metre);

    static assert(is(
        typeof(realConverted)
        == ConversionResult!(Quantity!(Length, double))));

    writeln("real.max is finite in source format: ",
        representedSource != real.infinity);
    writeln("narrowed double is finite: ",
        storedDouble == storedDouble
        && storedDouble <= double.max
        && storedDouble >= -double.max);
    writeln("round-trip narrowed double differs from real source: ",
        cast(real)storedDouble != representedSource);
    writeln("checkedQuantity status: ", realConverted.status);

    if (storedDouble == storedDouble
        && storedDouble <= double.max
        && storedDouble >= -double.max)
    {
        assert(realConverted.hasValue);
        assert(realConverted.status == ConversionStatus.exact);

        Quantity!(Length, double) q;
        assert(realConverted.tryValue(q));
        assert(q.canonicalValue == storedDouble);
    }
    else
    {
        assert(!realConverted.hasValue);
        assert(realConverted.status == ConversionStatus.nonFinite);
    }

    writeln(
        "R15 Probe 2 PASS: current overloads can lose or misclassify "
        ~ "represented source values before checked conversion observes them");

}