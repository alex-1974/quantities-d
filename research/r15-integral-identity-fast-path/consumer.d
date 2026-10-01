module r15_integral_identity_consumer;
import quantities.conversion;
import quantities.quantity : Quantity;
import quantities.length : Length,Metre;
import quantities.unit : DerivedUnit;
import quantities.ratio : ExactRatio;
import r15_integral_identity_kernel : identityLong,identityOrComposedLong;
import r15_floating_integral_kernel : qualifiedReal;
import r15_composed_kernel : IntegralRoundingMode;
import r15_rescale_kernel : Status;

alias NegativeUnit=DerivedUnit!(Metre.Dimension,ExactRatio!(-3,7));
struct NegativeSpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=NegativeUnit; }
static assert(!__traits(compiles, identityOrComposedLong!(Metre,Metre)(1L,false,IntegralRoundingMode.floor)));
static assert(!__traits(compiles, { enum r=1.5.checkedQuantityAs!(Length,Metre,long); }));
static assert(!__traits(compiles, { enum r=1.5F.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor); }));
static assert(!__traits(compiles, { enum r=Quantity!(Length,double).init.checkedInAs!(Metre,long); }));
// Tuple arithmetic itself remains CTFE-capable; represented float sources do not.
static assert(identityLong(ulong.max,-1,false,true,IntegralRoundingMode.towardZero).status==Status.overflow);
static assert(identityLong(1,63,true,false,IntegralRoundingMode.floor).value==long.min);
static assert(identityLong(1,-64,false,true,IntegralRoundingMode.ceiling).value==1);
static assert(identityLong(1UL<<63,-64,true,true,IntegralRoundingMode.nearestTiesAway).value==-1);
static assert(identityLong(ulong.max,-65,true,true,IntegralRoundingMode.nearestTiesAway).value==0);
static assert(identityLong(1,int.min,true,true,IntegralRoundingMode.floor).value==-1);

bool identityIntegralChecks() @safe pure nothrow @nogc
{
    const(float) f=-1.5F;
    immutable(double) d=1.5;
    const a=f.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor);
    const b=d.roundedQuantityAs!(Length,Metre,long,RoundingMode.ceiling);
    Quantity!(Length,long) value;
    if(!a.tryValue(value) || value.canonicalValue!=-2 || a.status!=ConversionStatus.inexact) return false;
    if(!b.tryValue(value) || value.canonicalValue!=2 || b.status!=ConversionStatus.inexact) return false;
    const c=d.checkedQuantityAs!(NegativeSpec,NegativeUnit,long);
    Quantity!(NegativeSpec,long) negativeValue;
    if(c.status!=ConversionStatus.inexact || c.tryValue(negativeValue)) return false;
    static if(qualifiedReal)
    {
        const(real) x=-1.5L;
        const z=x.roundedQuantityAs!(Length,Metre,long,RoundingMode.nearestTiesAway);
        if(!z.tryValue(value) || value.canonicalValue!=-2) return false;
        static if(real.mant_dig==64)
        {
            const(real) boundary=cast(real)ulong.max/2;
            static foreach(mode;[RoundingMode.towardZero,RoundingMode.floor,RoundingMode.ceiling,RoundingMode.nearestTiesAway])
            {{
                const over=boundary.roundedQuantityAs!(Length,Metre,long,mode);
                if(over.status!=ConversionStatus.overflow || over.tryValue(value)) return false;
            }}
        }
    }
    return true;
}
