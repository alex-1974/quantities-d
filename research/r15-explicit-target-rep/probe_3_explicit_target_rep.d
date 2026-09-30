module r15_probe_3_explicit_target_rep;

import std.stdio : writeln;
import std.traits : Unqual;
import quantities;

struct Capture(SourceRep, TargetRep, Spec, Unit)
{
    alias Source = SourceRep;
    alias Target = TargetRep;
    alias QuantitySpec = Spec;
    alias QuantityUnit = Unit;
}

auto checkedQuantityR15(Spec, Unit, TargetRep, SourceRep)(SourceRep value)
{
    return Capture!(
        Unqual!SourceRep,
        TargetRep,
        Spec,
        Unit)();
}

auto checkedInR15(Unit, TargetRep, Spec, SourceRep)(
    Quantity!(Spec, SourceRep) value)
{
    return Capture!(
        SourceRep,
        TargetRep,
        Spec,
        Unit)();
}

void main()
{
    writeln("=== CONSTRUCTION SOURCE CAPTURE ===");

    auto a =
        ulong.max.checkedQuantityR15!(
            Length,
            Metre,
            float);

    static assert(is(typeof(a.Source) == ulong));
    static assert(is(typeof(a.Target) == float));

    const real sourceReal = real.max;
    auto b =
        sourceReal.checkedQuantityR15!(
            Length,
            Metre,
            double);

    static assert(is(typeof(b.Source) == real));
    static assert(is(typeof(b.Target) == double));

    immutable double sourceDouble = 1.0;
    auto c =
        sourceDouble.checkedQuantityR15!(
            Length,
            Metre,
            float);

    static assert(is(typeof(c.Source) == double));
    static assert(is(typeof(c.Target) == float));

    writeln("ulong source captured as: ", a.Source.stringof);
    writeln("real source captured as:  ", b.Source.stringof);
    writeln("double source captured as:", c.Source.stringof);

    writeln();
    writeln("=== EXTRACTION SOURCE/TARGET CAPTURE ===");

    auto q =
        Quantity!(Length, real).fromCanonical(1.0L);

    auto e =
        q.checkedInR15!(
            Metre,
            double);

    static assert(is(typeof(e.Source) == real));
    static assert(is(typeof(e.Target) == double));

    writeln("Quantity source Rep: ", e.Source.stringof);
    writeln("requested target Rep:", e.Target.stringof);

    writeln();
    writeln("R15 Probe 3 PASS: explicit TargetRep + deduced SourceRep preserves source identity");
}
