module r15_float_api_runner;
import r15_api_consumer : consumerChecks;
import r15_float_api_consumer : floatingConsumerChecks;
import quantities.conversion;
import quantities.quantity : Quantity, quantity;
import quantities.length : Length, Metre, InternationalFoot, USSurveyFoot;
import quantities.unit : DerivedUnit;
import quantities.ratio : ExactRatio;
import r15_rescale_kernel : fromBits, storedBits;
import r15_floating_integral_kernel : qualifiedReal;
import std.conv : to;
import std.math : ldexp;
import std.stdio : stdin, write, writeln;
import std.string : split;

import r15_float_api_fixtures;

void output(T)(ConversionResult!T result)
{
    T value;
    if (!result.tryValue(value)) write(result.status," -");
    else static if (is(T == Quantity!(Spec,Rep),Spec,Rep)) write(result.status," ",storedBits(value.canonicalValue));
    else write(result.status," ",storedBits(value));
}
void output(T)(ExactResult!T result)
{
    T value;
    if (result.tryValue(value))
    {
        static if (is(T == Quantity!(Spec,Rep),Spec,Rep)) write("value ",storedBits(value.canonicalValue));
        else write("value ",storedBits(value));
    }
    else { ExactFailure failure; result.tryFailure(failure); write("failure ",failure); }
}

void emit(T,Spec,Unit,S)(S source,string intent,int mode)
{
    const q=source.quantity!(Spec,Spec.CanonicalUnit);
    if(intent=="C")
    {
        output(source.checkedQuantityAs!(Spec,Unit,T)); write(" | ");
        output(q.checkedInAs!(Unit,T));
    }
    else
    {
        output(source.exactQuantityAs!(Spec,Unit,T)); write(" | ");
        output(q.exactInAs!(Unit,T));
    }
    writeln();
}

void dispatch(T,S)(S source,string intent,int mode,int pair)
{
    switch(pair)
    {
        case 0: emit!(T,Length,Metre)(source,intent,mode); break;
        case 1: emit!(T,Length,InternationalFoot)(source,intent,mode); break;
        case 2: emit!(T,Length,USSurveyFoot)(source,intent,mode); break;
        case 3: emit!(T,WideSpec,WideFrom)(source,intent,mode); break;
        case 4: emit!(T,FootSpec,USSurveyFoot)(source,intent,mode); break;
        case 5: emit!(T,NegativeSpec,InternationalFoot)(source,intent,mode); break;
        case 6: emit!(T,Length,DirectRoundingUnit)(source,intent,mode); break;
        case 7: emit!(T,Length,NearMaxUnit)(source,intent,mode); break;
        default: throw new Exception("unknown Unit pair");
    }
}

void selectTarget(S)(S source,string target,string intent,int pair)
{
    if(target=="F") dispatch!float(source,intent,0,pair);
    else dispatch!double(source,intent,0,pair);
}

void main(string[] args)
{
    if(args.length>1) { writeln(real.mant_dig," ",real.min_exp," ",real.max_exp); return; }
    if(!consumerChecks() || !floatingConsumerChecks()) throw new Exception("R15 consumer invariant/attribute gate failed");
    foreach(line;stdin.byLineCopy)
    {
        const f=line.split;
        const target=f[1];
        const intent=f[2];
        const pair=f[3].to!int;
        if(f[0]=="L") selectTarget(f[4].to!long,target,intent,pair);
        else if(f[0]=="U") selectTarget(f[4].to!ulong,target,intent,pair);
        else if(f[0]=="F") selectTarget(fromBits!float(f[4].to!ulong),target,intent,pair);
        else if(f[0]=="D") selectTarget(fromBits!double(f[4].to!ulong),target,intent,pair);
        else static if(qualifiedReal)
        {
            real source;
            if(f[0]=="R") { source=ldexp(cast(real)f[4].to!ulong,f[5].to!int); if(f[6]=="1") source=-source; }
            else if(f[0]=="N") source=real.nan;
            else if(f[0]=="P") source=real.infinity;
            else if(f[0]=="M") source=-real.infinity;
            else throw new Exception("unknown source");
            selectTarget(source,target,intent,pair);
        }
        else throw new Exception("unsupported real format");
    }
}
