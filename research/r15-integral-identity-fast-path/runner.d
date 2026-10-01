module r15_integral_identity_runner;
import r15_api_consumer : consumerChecks;
import r15_integral_identity_consumer : identityIntegralChecks;
import r15_integral_identity_kernel : identityLong;
import r15_composed_kernel : IntegralRoundingMode;
import quantities.conversion;
import quantities.quantity : Quantity, quantity;
import quantities.length : Length, Metre, InternationalFoot, USSurveyFoot;
import quantities.unit : DerivedUnit;
import quantities.ratio : ExactRatio;
import r15_rescale_kernel : fromBits;
import r15_floating_integral_kernel : qualifiedReal;
import std.conv : to;
import std.math : ldexp;
import std.stdio : stdin, write, writeln;
import std.string : split;

alias WideFrom = DerivedUnit!(Metre.Dimension,ExactRatio!(long.max,long.max-18));
alias WideTo = DerivedUnit!(Metre.Dimension,ExactRatio!(long.max-20,long.max-6));
alias NegativeUnit = DerivedUnit!(Metre.Dimension,ExactRatio!(long.min,long.max));
struct WideSpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=WideTo; }
struct FootSpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=InternationalFoot; }
struct NegativeSpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=NegativeUnit; }

void output(T)(ConversionResult!T result)
{
    T value;
    if (!result.tryValue(value)) write(result.status," -");
    else static if (is(T == Quantity!(Spec,Rep),Spec,Rep)) write(result.status," ",value.canonicalValue);
    else write(result.status," ",value);
}
void output(T)(ExactResult!T result)
{
    T value;
    if (result.tryValue(value))
    {
        static if (is(T == Quantity!(Spec,Rep),Spec,Rep)) write("value ",value.canonicalValue);
        else write("value ",value);
    }
    else { ExactFailure failure; result.tryFailure(failure); write("failure ",failure); }
}

void emit(Spec,Unit,S)(S source,string intent,int mode)
{
    const q=source.quantity!(Spec,Spec.CanonicalUnit);
    if (intent=="C")
    {
        output(source.checkedQuantityAs!(Spec,Unit,long)); write(" | ");
        output(q.checkedInAs!(Unit,long));
    }
    else if (intent=="E")
    {
        output(source.exactQuantityAs!(Spec,Unit,long)); write(" | ");
        output(q.exactInAs!(Unit,long));
    }
    else
    {
        modeSwitch: final switch(cast(RoundingMode)mode)
        {
            static foreach (m; [RoundingMode.towardZero,RoundingMode.floor,
                               RoundingMode.ceiling,RoundingMode.nearestTiesAway])
            {
                case m:
                    output(source.roundedQuantityAs!(Spec,Unit,long,m)); write(" | ");
                    output(q.roundedInAs!(Unit,long,m)); break modeSwitch;
            }
        }
    }
    writeln;
}

void dispatch(S)(S source,string intent,int mode,int pair)
{
    switch(pair)
    {
        case 0: emit!(Length,Metre)(source,intent,mode); break;
        case 1: emit!(Length,InternationalFoot)(source,intent,mode); break;
        case 2: emit!(Length,USSurveyFoot)(source,intent,mode); break;
        case 3: emit!(WideSpec,WideFrom)(source,intent,mode); break;
        case 4: emit!(FootSpec,USSurveyFoot)(source,intent,mode); break;
        case 5: emit!(NegativeSpec,InternationalFoot)(source,intent,mode); break;
        default: throw new Exception("unknown Unit pair");
    }
}

void main(string[] args)
{
    if(args.length>1) { writeln(real.mant_dig," ",real.min_exp," ",real.max_exp); return; }
    if(!identityIntegralChecks()) throw new Exception("Probe 19 consumer gate failed");
    if(!consumerChecks()) throw new Exception("R15 consumer invariant/attribute gate failed");
    foreach(line;stdin.byLineCopy)
    {
        const f=line.split;
        if(f[0]=="T")
        {
            const result=identityLong(f[4].to!ulong,f[5].to!int,f[6]=="1",f[1]=="R",
                cast(IntegralRoundingMode)f[2].to!int);
            if(result.hasValue) writeln(result.status," ",result.value);
            else writeln(result.status," -");
            continue;
        }
        const intent=f[1];
        const mode=f[2].to!int;
        const pair=f[3].to!int;
        if(f[0]=="F") dispatch(fromBits!float(f[4].to!ulong),intent,mode,pair);
        else if(f[0]=="D") dispatch(fromBits!double(f[4].to!ulong),intent,mode,pair);
        else static if(qualifiedReal)
        {
            real source;
            if(f[0]=="R") { source=ldexp(cast(real)f[4].to!ulong,f[5].to!int); if(f[6]=="1") source=-source; }
            else if(f[0]=="N") source=real.nan;
            else if(f[0]=="P") source=real.infinity;
            else if(f[0]=="M") source=-real.infinity;
            else throw new Exception("unknown source");
            dispatch(source,intent,mode,pair);
        }
        else throw new Exception("unsupported real format");
    }
}
