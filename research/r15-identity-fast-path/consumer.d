module r15_identity_consumer;
import quantities.conversion;
import quantities.quantity : Quantity,quantity;
import quantities.length : Length,Metre;
import quantities.ratio : ExactRatio;
import r15_identity_kernel : identityInclusion;
import r15_rescale_kernel : fromBits,storedBits;

struct NegativeMetre { alias Dimension=Length.Dimension; alias Scale=ExactRatio!(-1,1); }
struct NegativeSpec { alias Dimension=Length.Dimension; alias CanonicalUnit=NegativeMetre; }
struct EquivalentMetre { alias Dimension=Length.Dimension; alias Scale=ExactRatio!(2,2); }

static assert(identityInclusion!(double,EquivalentMetre,Metre,const(float)));
static assert(identityInclusion!(float,NegativeMetre,NegativeMetre,float));
static assert(!identityInclusion!(float,Metre,Metre,double));
static assert(!identityInclusion!(double,NegativeMetre,Metre,float));
static assert(!__traits(compiles, { enum r=1F.checkedQuantityAs!(Length,Metre,double); }));
static assert(!__traits(compiles, { enum r=1F.exactQuantityAs!(Length,Metre,float); }));
static assert(!__traits(compiles, { enum r=1.0.checkedQuantityAs!(Length,Metre,double); }));
static assert(!__traits(compiles, { enum q=1F.quantity!(Length,Metre); enum r=q.checkedInAs!(Metre,double); }));

@safe pure nothrow @nogc
bool identityChecks()
{
    immutable(float) source=fromBits!float(0x80000000UL);
    const r=source.exactQuantityAs!(NegativeSpec,NegativeMetre,double);
    Quantity!(NegativeSpec,double) d;
    if(!r.tryValue(d) || storedBits(d.canonicalValue)!=(1UL<<63)) return false;
    const q=source.quantity!(NegativeSpec,NegativeMetre);
    const e=q.checkedInAs!(NegativeMetre,float);
    float f;
    if(e.status!=ConversionStatus.exact || !e.tryValue(f)
        || storedBits(f)!=0x80000000UL) return false;
    const flip=source.checkedQuantityAs!(Length,NegativeMetre,double);
    Quantity!(Length,double) positive;
    if(!flip.tryValue(positive) || storedBits(positive.canonicalValue)!=0UL) return false;
    const normalized=1F.exactQuantityAs!(Length,EquivalentMetre,double);
    if(!normalized.tryValue(positive) || positive.canonicalValue!=1.0) return false;
    // Exercise every highest-set-bit position in binary32 subnormal fractions.
    foreach(top;0..23)
    {
        const tiny=fromBits!float(1UL<<top);
        const converted=tiny.exactQuantityAs!(Length,Metre,double);
        if(!converted.tryValue(positive)
            || storedBits(positive.canonicalValue)!=(cast(ulong)(top+874)<<52)) return false;
    }
    return true;
}
