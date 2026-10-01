module r15_float_api_consumer;
import quantities.conversion;
import quantities.quantity : Quantity, quantity;
import quantities.length : Length,Metre,InternationalFoot;
import r15_float_api_fixtures : DirectRoundingUnit,NearMaxUnit;
import r15_rescale_kernel : storedBits,fromBits;
import r15_floating_integral_kernel : qualifiedReal;

static assert(!__traits(compiles, 1.0.checkedQuantityAs!(Length,Metre,real)));
static assert(!__traits(compiles, 1.0.checkedQuantityAs!(Length,Metre,ulong)));
static assert(!__traits(compiles, 1.checkedQuantityAs!(Length,Metre,float)));
static assert(!__traits(compiles, true.exactQuantityAs!(Length,Metre,double)));
static assert(!__traits(compiles, "1".checkedQuantityAs!(Length,Metre,float)));
static assert(!__traits(compiles, 1.0.roundedQuantityAs!(Length,Metre,float,RoundingMode.floor)));
static assert(!__traits(compiles, { auto q=1.0.quantity!(Length,Metre); return q.roundedInAs!(Metre,double,RoundingMode.floor); }));
static assert(!__traits(compiles, { enum r=1.0.checkedQuantityAs!(Length,Metre,float); }));
static assert(!__traits(compiles, { enum r=1L.checkedQuantityAs!(Length,Metre,double); }));
static assert(is(typeof(ulong.max.checkedQuantityAs!(Length,Metre,float)) == ConversionResult!(Quantity!(Length,float))));

// All checks execute in release builds too. No assert carries a side effect.
@safe pure nothrow @nogc
bool floatingConsumerChecks()
{
    const(double) source=1.0;
    const witness=source.checkedQuantityAs!(Length,DirectRoundingUnit,float);
    Quantity!(Length,float) value;
    if(witness.status!=ConversionStatus.inexact || !witness.tryValue(value)
        || storedBits(value.canonicalValue)!=0x3f800001UL) return false;
    // Negative control: the binary64 intermediate erases the decisive low bit.
    const middle=source.checkedQuantityAs!(Length,DirectRoundingUnit,double);
    Quantity!(Length,double) intermediate;
    if(!middle.tryValue(intermediate)
        || storedBits(cast(float)intermediate.canonicalValue)!=0x3f800000UL) return false;
    const range=double.max.checkedQuantityAs!(Length,NearMaxUnit,double);
    if(range.hasValue || range.status!=ConversionStatus.overflow) return false;
    const large=ulong.max.checkedQuantityAs!(Length,Metre,double);
    if(large.status!=ConversionStatus.inexact || !large.tryValue(intermediate)
        || storedBits(intermediate.canonicalValue)!=0x43f0000000000000UL) return false;
    const exact=ulong.max.exactQuantityAs!(Length,Metre,double);
    ExactFailure failure;
    if(exact.hasValue || !exact.tryFailure(failure) || failure!=ExactFailure.inexact) return false;
    const(float) tiny=fromBits!float(1);
    const widened=tiny.exactQuantityAs!(Length,Metre,double);
    if(!widened.tryValue(intermediate) || storedBits(intermediate.canonicalValue)!=0x36a0000000000000UL) return false;
    immutable(double) half=1.5;
    const narrowed=half.exactQuantityAs!(Length,Metre,float);
    if(!narrowed.tryValue(value) || value.canonicalValue!=1.5F) return false;
    double nz=fromBits!double(1UL<<63);
    const q=nz.quantity!(Length,Metre);
    const zero=q.checkedInAs!(InternationalFoot,float);
    float extracted;
    if(zero.status!=ConversionStatus.exact || !zero.tryValue(extracted)
        || storedBits(extracted)!=0x80000000UL) return false;
    float outputValue=42;
    const nf=double.nan.quantity!(Length,Metre).checkedInAs!(Metre,float);
    if(nf.status!=ConversionStatus.nonFinite || nf.tryValue(outputValue)
        || outputValue==outputValue) return false; // D out resets to float.init (NaN), not 42.
    const small=1L.exactQuantityAs!(Length,Metre,float);
    if(!small.tryValue(value) || value.canonicalValue!=1F) return false;
    static if(qualifiedReal)
    {
        const(real) r=1.5L;
        const rr=r.exactQuantityAs!(Length,Metre,float);
        if(!rr.tryValue(value) || value.canonicalValue!=1.5F) return false;
    }
    return true;
}
