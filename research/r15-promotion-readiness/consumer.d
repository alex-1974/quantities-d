module r15_promotion_consumer;
// Public API names/types below are imported solely through the package root.
import quantities;
import r15_integral_source_consumer : integralConsumerChecks;
import r15_floating_integral_kernel : qualifiedReal;
import std.stdio : writeln;

static assert(is(typeof(checkedQuantityAs!(Length,Metre,long)(1L))==ConversionResult!(Quantity!(Length,long))));
static assert(!__traits(compiles, 1.0.checkedQuantityAs!(Length,Metre,real)));
static assert(!__traits(compiles, 1L.checkedQuantityAs!(Length,Metre,real)));
static assert(!__traits(compiles, 1L.checkedQuantityAs!(Length,Metre,long,ulong)));
static assert(!__traits(compiles, {enum x=1L.checkedQuantityAs!(Length,Metre,double);}));
static assert(!__traits(compiles, {enum x=1.5F.checkedQuantityAs!(Length,Metre,long);}));
static assert(!__traits(compiles, {enum x=1.5.exactQuantityAs!(Length,Metre,float);}));
static if(qualifiedReal)
{
    static assert(!__traits(compiles, {enum x=1.5L.checkedQuantityAs!(Length,Metre,long);}));
    static assert(!__traits(compiles, {enum x=1.5L.exactQuantityAs!(Length,Metre,long);}));
    static assert(!__traits(compiles, {enum x=1.5L.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor);}));
    static assert(!__traits(compiles, {enum q=1.5L.quantity!(Length,Metre);enum x=q.checkedInAs!(Metre,long);}));
    static assert(!__traits(compiles, {enum q=1.5L.quantity!(Length,Metre);enum x=q.exactInAs!(Metre,long);}));
    static assert(!__traits(compiles, {enum q=1.5L.quantity!(Length,Metre);enum x=q.roundedInAs!(Metre,long,RoundingMode.floor);}));
}

bool rootChecks() @safe pure nothrow @nogc
{
    Quantity!(Length,long) value;
    long scalar;
    const c=checkedQuantityAs!(Length,Metre,long)(2UL);
    const e=exactQuantityAs!(Length,Metre,long)(2L);
    const r=roundedQuantityAs!(Length,Metre,long,RoundingMode.floor)(2L);
    immutable q=2L.quantity!(Length,Metre);
    const ci=checkedInAs!(Metre,long)(q);
    const ei=exactInAs!(Metre,long)(q);
    const ri=roundedInAs!(Metre,long,RoundingMode.floor)(q);
    if(!c.tryValue(value) || value.canonicalValue!=2 || !e.tryValue(value) || value.canonicalValue!=2 ||
        !r.tryValue(value) || value.canonicalValue!=2 || !ci.tryValue(scalar) || scalar!=2 ||
        !ei.tryValue(scalar) || scalar!=2 || !ri.tryValue(scalar) || scalar!=2) return false;
    const ufc=2UL.checkedQuantityAs!(Length,Metre,long);
    const ufe=2L.exactQuantityAs!(Length,Metre,long);
    const ufr=2L.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor);
    const ufci=q.checkedInAs!(Metre,long);
    const ufei=q.exactInAs!(Metre,long);
    const ufri=q.roundedInAs!(Metre,long,RoundingMode.floor);
    return ufc.tryValue(value) && value.canonicalValue==2 && ufe.tryValue(value) &&
        value.canonicalValue==2 && ufr.tryValue(value) && value.canonicalValue==2 &&
        ufci.tryValue(scalar) && scalar==2 && ufei.tryValue(scalar) && scalar==2 &&
        ufri.tryValue(scalar) && scalar==2 && integralConsumerChecks();
}
static assert(rootChecks());
void main()
{
    if(!rootChecks()) throw new Exception("Root request/CTFE contract failed");
    static if(qualifiedReal)
    {
        const(real) source=1.5L;
        const r=source.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor);
        Quantity!(Length,long) value;
        if(!r.tryValue(value) || value.canonicalValue!=1 || r.status!=ConversionStatus.inexact)
            throw new Exception("real runtime request changed");
    }
    writeln("R15 Probe 21 PASS: package-root free/UFCS forms, integral CTFE, floating/real CTFE rejection and runtime contract");
}
