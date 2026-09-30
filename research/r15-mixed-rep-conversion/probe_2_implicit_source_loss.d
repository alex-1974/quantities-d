module r15_probe_2_implicit_source_loss;

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
    assert(cast(double)representedSource == double.infinity);

    auto realConverted =
        representedSource.checkedQuantity!(Length, Metre);

    static assert(is(
        typeof(realConverted)
        == ConversionResult!(Quantity!(Length, double))));

    writeln("real.max is finite in source format: ",
        representedSource != real.infinity);
    writeln("pre-call cast(double) source is infinity: ",
        cast(double)representedSource == double.infinity);
    writeln("checkedQuantity status: ", realConverted.status);

    assert(!realConverted.hasValue);
    assert(realConverted.status == ConversionStatus.nonFinite);

    writeln(
        "R15 Probe 2 PASS: current overloads can lose or misclassify "
        ~ "represented source values before checked conversion observes them");

}