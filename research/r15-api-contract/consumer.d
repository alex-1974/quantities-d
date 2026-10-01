module r15_contract_consumer;
import quantities.conversion;
import quantities.quantity : Quantity,quantity;
import quantities.length : Length,Metre,InternationalFoot;
import quantities.ratio : ExactRatio;
import r15_rescale_kernel : fromBits,storedBits;
import r15_api_consumer : consumerChecks;
import r15_float_api_consumer : floatingConsumerChecks;
import std.math : ldexp;
import std.stdio : writeln;

// Only the request belongs in the public outer template argument list.
static assert(!__traits(compiles, { ulong source; return source.checkedQuantityAs!(Length,Metre,long,double); }));
static assert(!__traits(compiles, 1.checkedQuantityAs!(Length,Metre,float,long)));
static assert(!__traits(compiles, 1.exactQuantityAs!(Length,Metre,float,long)));
static assert(!__traits(compiles, 1.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor,double)));
static assert(!__traits(compiles, { auto q=1.0.quantity!(Length,Metre); return q.checkedInAs!(Metre,float,Length,double); }));
static assert(!__traits(compiles, { auto q=1.0.quantity!(Length,Metre); return q.exactInAs!(Metre,float,Length,double); }));
static assert(!__traits(compiles, { auto q=1.0.quantity!(Length,Metre); return q.roundedInAs!(Metre,long,RoundingMode.floor,Length,double); }));

enum a = 1L << 62;
struct FromBoundary { alias Dimension=Length.Dimension; alias Scale=ExactRatio!(a-1,a); }
struct CanonBoundary { alias Dimension=Length.Dimension; alias Scale=ExactRatio!(a,a+1); }
struct BoundarySpec { alias Dimension=Length.Dimension; alias CanonicalUnit=CanonBoundary; }
struct HalfMetre { alias Dimension=Length.Dimension; alias Scale=ExactRatio!(1,2); }

@safe pure nothrow @nogc
bool contractChecks()
{
    // The positive exact value is 2^63 - 2^-61: above long.max, but
    // truncating it would yield long.max. Range rejection precedes every mode.
    double upper=ldexp(1.0,63);
    const qUpper=upper.quantity!(BoundarySpec,CanonBoundary);
    const qLower=(-upper).quantity!(BoundarySpec,CanonBoundary);
    const checked=upper.checkedQuantityAs!(BoundarySpec,FromBoundary,long);
    const exact=upper.exactQuantityAs!(BoundarySpec,FromBoundary,long);
    ExactFailure failure;
    if(checked.hasValue || checked.status!=ConversionStatus.overflow
        || exact.hasValue || !exact.tryFailure(failure) || failure!=ExactFailure.overflow) return false;
    static foreach(mode; [RoundingMode.towardZero,RoundingMode.floor,
        RoundingMode.ceiling,RoundingMode.nearestTiesAway])
    {
        {
            const c=upper.roundedQuantityAs!(BoundarySpec,FromBoundary,long,mode);
            const e=qLower.roundedInAs!(FromBoundary,long,mode);
            if(c.hasValue || c.status!=ConversionStatus.overflow
                || e.hasValue || e.status!=ConversionStatus.overflow) return false;
        }
    }
    // Interior +/-1.5 exercises all four policies without a range failure.
    static foreach(i,mode; [RoundingMode.towardZero,RoundingMode.floor,
        RoundingMode.ceiling,RoundingMode.nearestTiesAway])
    {
        {
            enum positives=[1L,1L,2L,2L];
            enum negatives=[-1L,-2L,-1L,-2L];
            const c=1.5.roundedQuantityAs!(Length,Metre,long,mode);
            const q=(-1.5).quantity!(Length,Metre);
            const e=q.roundedInAs!(Metre,long,mode);
            Quantity!(Length,long) value;
            long scalar;
            if(c.status!=ConversionStatus.inexact || !c.tryValue(value)
                || value.canonicalValue!=positives[i]
                || e.status!=ConversionStatus.inexact || !e.tryValue(scalar)
                || scalar!=negatives[i]) return false;
        }
    }
    // A total-exact Rep inclusion is not a proof of exact rational Unit rescale.
    const float one=1F;
    const scaled=one.checkedQuantityAs!(Length,InternationalFoot,double);
    const required=one.exactQuantityAs!(Length,InternationalFoot,double);
    if(!scaled.hasValue || scaled.status!=ConversionStatus.inexact
        || required.hasValue || !required.tryFailure(failure) || failure!=ExactFailure.inexact) return false;
    // Underflow is representational loss, not mathematical target-range overflow.
    const tiny=fromBits!float(1);
    const under=tiny.checkedQuantityAs!(Length,HalfMetre,float);
    const negUnder=(-tiny).checkedQuantityAs!(Length,HalfMetre,float);
    const exactUnder=tiny.exactQuantityAs!(Length,HalfMetre,float);
    Quantity!(Length,float) fv;
    if(under.status!=ConversionStatus.inexact || !under.tryValue(fv)
        || storedBits(fv.canonicalValue)!=0UL) return false;
    if(negUnder.status!=ConversionStatus.inexact || !negUnder.tryValue(fv)
        || storedBits(fv.canonicalValue)!=0x80000000UL) return false;
    if(exactUnder.hasValue || !exactUnder.tryFailure(failure) || failure!=ExactFailure.inexact) return false;
    // Free-function and UFCS forms use the same request and result semantics.
    const direct=checkedQuantityAs!(Length,Metre,float)(1.5);
    const ufcs=1.5.checkedQuantityAs!(Length,Metre,float);
    if(!direct.tryValue(fv) || fv.canonicalValue!=1.5F
        || !ufcs.tryValue(fv) || fv.canonicalValue!=1.5F) return false;
    const de=exactQuantityAs!(Length,Metre,float)(1.5);
    const dr=roundedQuantityAs!(Length,Metre,long,RoundingMode.floor)(1.5);
    Quantity!(Length,long) lv;
    if(!de.tryValue(fv) || !dr.tryValue(lv) || lv.canonicalValue!=1) return false;
    immutable q=1.5.quantity!(Length,Metre);
    const ec=checkedInAs!(Metre,float)(q);
    const ee=exactInAs!(Metre,float)(q);
    const er=roundedInAs!(Metre,long,RoundingMode.floor)(q);
    float scalar;
    long integer;
    if(!ec.tryValue(scalar) || scalar!=1.5F || !ee.tryValue(scalar)
        || scalar!=1.5F || !er.tryValue(integer) || integer!=1) return false;
    return true;
}

void main()
{
    if(!consumerChecks() || !floatingConsumerChecks() || !contractChecks())
        throw new Exception("R15 Probe 16 contract gate failed");
    writeln("R15 Probe 16 PASS: request arity, UFCS/free calls, qualifiers, range-first rounding, underflow, Unit exactness");
}
