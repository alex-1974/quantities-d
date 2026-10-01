module conversion_as_integral;
import quantities;



import conversion_as_integral_fixtures;

static assert(is(typeof(long.min.checkedQuantityAs!(Length,Metre,long))==ConversionResult!(Quantity!(Length,long))));
static assert(is(typeof(ulong.max.exactQuantityAs!(Length,Metre,long))==ExactResult!(Quantity!(Length,long))));
static assert(!__traits(compiles, 1.checkedQuantityAs!(Length,Metre,long)));
static assert(!__traits(compiles, 1L.checkedQuantityAs!(Length,Metre,ulong)));
static assert(!__traits(compiles, 1L.checkedQuantityAs!(Length,Metre,real)));
static assert(!__traits(compiles, 1L.roundedQuantityAs!(Length,Metre,long,cast(RoundingMode)99)));
static assert(!__traits(compiles, 1L.checkedQuantityAs!(Length,Metre,long,ulong)));
static assert(!__traits(compiles, { enum r=1.5.checkedQuantityAs!(Length,Metre,long); }));

bool integralConsumerChecks() @safe pure nothrow @nogc
{
    Quantity!(Length,long) outQ;
    long scalar;
    ExactFailure failure;
    const(long) minimum=long.min;
    immutable(ulong) maximum=ulong.max;
    const identity=minimum.checkedQuantityAs!(Length,Metre,long);
    if(identity.status!=ConversionStatus.exact || !identity.tryValue(outQ) || outQ.canonicalValue!=long.min) return false;
    const upper=cast(ulong)long.max;
    const exact=upper.exactQuantityAs!(Length,Metre,long);
    if(!exact.tryValue(outQ) || outQ.canonicalValue!=long.max) return false;
    const overflow=maximum.exactQuantityAs!(Length,Metre,long);
    if(overflow.hasValue || !overflow.tryFailure(failure) || failure!=ExactFailure.overflow) return false;
    const negative=1UL.checkedQuantityAs!(Length,HugeNegativeUnit,long);
    if(!negative.tryValue(outQ) || outQ.canonicalValue!=long.min) return false;
    const inverse=minimum.quantity!(Length,Metre).exactInAs!(HugeNegativeUnit,long);
    if(!inverse.tryValue(scalar) || scalar!=1) return false;
    const checked=3L.checkedQuantityAs!(Length,HalfUnit,long);
    const inexact=3UL.exactQuantityAs!(Length,HalfUnit,long);
    if(checked.hasValue || checked.status!=ConversionStatus.inexact || inexact.hasValue ||
        !inexact.tryFailure(failure) || failure!=ExactFailure.inexact) return false;
    // All six free forms and UFCS requests are executable at CTFE on integral sources.
    const freeChecked=checkedQuantityAs!(Length,Metre,long)(1L);
    const freeExact=exactQuantityAs!(Length,Metre,long)(1UL);
    const freeRounded=roundedQuantityAs!(Length,HalfUnit,long,RoundingMode.floor)(3L);
    immutable q=2UL.quantity!(Length,Metre);
    const freeIn=checkedInAs!(DoubleUnit,long)(q);
    const freeExactIn=exactInAs!(DoubleUnit,long)(q);
    const freeRoundIn=roundedInAs!(DoubleUnit,long,RoundingMode.floor)(q);
    if(!freeChecked.tryValue(outQ) || outQ.canonicalValue!=1 || !freeExact.tryValue(outQ) ||
        outQ.canonicalValue!=1 || !freeRounded.tryValue(outQ) || outQ.canonicalValue!=1 ||
        !freeIn.tryValue(scalar) || scalar!=1 || !freeExactIn.tryValue(scalar) || scalar!=1 ||
        !freeRoundIn.tryValue(scalar) || scalar!=1) return false;
    static foreach(i,mode;[RoundingMode.towardZero,RoundingMode.floor,RoundingMode.ceiling,RoundingMode.nearestTiesAway])
    {{
        enum positive=[1L,1L,2L,2L],negativeValues=[-1L,-2L,-1L,-2L];
        const rounded=3UL.roundedQuantityAs!(Length,HalfUnit,long,mode);
        const extraction=(-3L).quantity!(Length,Metre).roundedInAs!(DoubleUnit,long,mode);
        if(rounded.status!=ConversionStatus.inexact || !rounded.tryValue(outQ) || outQ.canonicalValue!=positive[i] ||
            extraction.status!=ConversionStatus.inexact || !extraction.tryValue(scalar) || scalar!=negativeValues[i]) return false;
        const identityOver=maximum.roundedQuantityAs!(Length,Metre,long,mode);
        const halfOver=maximum.roundedQuantityAs!(Length,HalfUnit,long,mode);
        const boundaryOver=(1UL<<63).roundedQuantityAs!(BoundarySpec,FromBoundary,long,mode);
        const belowMin=minimum.quantity!(BoundarySpec,CanonBoundary).roundedInAs!(FromBoundary,long,mode);
        // ulong.max/2 = long.max+0.5; all modes fail BEFORE truncation could fit.
        if(identityOver.hasValue || identityOver.status!=ConversionStatus.overflow ||
            halfOver.hasValue || halfOver.status!=ConversionStatus.overflow ||
            boundaryOver.hasValue || boundaryOver.status!=ConversionStatus.overflow ||
            belowMin.hasValue || belowMin.status!=ConversionStatus.overflow) return false;
    }}
    const zero=0UL.checkedQuantityAs!(TinySpec,HugeNegativeUnit,long);
    Quantity!(TinySpec,long) tiny;
    if(zero.status!=ConversionStatus.exact || !zero.tryValue(tiny) || tiny.canonicalValue!=0) return false;
    // D out parameters reset to .init on failure, even after a successful extraction.
    scalar=99;
    const missing=maximum.quantity!(Length,Metre).checkedInAs!(Metre,long);
    if(missing.tryValue(scalar) || scalar!=long.init || missing.status!=ConversionStatus.overflow) return false;
    return true;
}
enum ctfePassed=integralConsumerChecks();
static assert(ctfePassed,"Integral API must preserve the same result contract at CTFE.");
