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
    writeln("=== REAL PRE-CALL NARROWING WITNESS ===");

    // On the current qualified real80-like target this is the next represented
    // real above 1.0L. It is not representable in binary64.
    static assert(real.mant_dig > double.mant_dig);

    const real representedSource =
        1.0L + real.epsilon;

    assert(representedSource != 1.0L);
    assert(cast(double)representedSource == 1.0);

    auto converted =
        representedSource.checkedQuantity!(Length, Metre);

    static assert(is(
        typeof(converted)
        == ConversionResult!(Quantity!(Length, double))));

    assert(converted.hasValue);
    assert(converted.status == ConversionStatus.exact);

    Quantity!(Length, double) q;
    assert(converted.tryValue(q));

    writeln("represented real source differs from 1.0L: ",
        representedSource != 1.0L);
    writeln("pre-call cast(double) source == 1.0: ",
        cast(double)representedSource == 1.0);
    writeln("checkedQuantity status: ", converted.status);
    writeln("stored canonical double == 1.0: ",
        q.canonicalValue == 1.0);

    // The API reports exact only because the narrowing already happened during
    // overload argument conversion. This violates the intended represented-
    // source exactness boundary.
    assert(q.canonicalValue != cast(double)(representedSource + real.epsilon)
        || representedSource != cast(real)q.canonicalValue);

    writeln(
        "R15 Probe 2 PASS: current real source can lose information "
        ~ "before checked conversion observes it");
}
