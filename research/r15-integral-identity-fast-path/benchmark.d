module r15_integral_identity_benchmark;
import quantities.conversion;
import r15_integral_identity_codegen;
import quantities.quantity : Quantity;
import quantities.length : Length,Metre,InternationalFoot;
import r15_float_api_fixtures : WideSpec,WideFrom,DirectRoundingUnit;
import r15_floating_target_kernel : composedFloating;
import r15_floating_integral_kernel : convertFloatingLong,qualifiedReal;
import r15_composed_kernel : IntegralRoundingMode;
import r15_rescale_kernel : Status,storedBits,fromBits;
import std.datetime.stopwatch : StopWatch;
import std.algorithm.sorting : sort;
import std.stdio : writeln,writefln;
import std.math : ldexp;

struct Observation { ConversionStatus status; bool present; ulong bits; }

@safe pure nothrow @nogc
Observation observe(Spec,T)(ConversionResult!(Quantity!(Spec,T)) result)
{
    Quantity!(Spec,T) value;
    const present=result.tryValue(value);
    ulong bits;
    if(present)
    {
        static if(is(T==long)) bits=cast(ulong)value.canonicalValue;
        else bits=storedBits(value.canonicalValue);
    }
    return Observation(result.status,present,bits);
}
@safe pure nothrow @nogc
ConversionStatus mapped(Status status)
{
    final switch(status)
    {
        case Status.exact: return ConversionStatus.exact;
        case Status.inexact: return ConversionStatus.inexact;
        case Status.overflow: return ConversionStatus.overflow;
        case Status.nonFinite: return ConversionStatus.nonFinite;
    }
}
@safe pure nothrow @nogc
Observation api(T,Spec,Unit,bool rounded,S)(S source)
{
    static if(rounded) return observe(source.roundedQuantityAs!(Spec,Unit,T,RoundingMode.floor));
    else return observe(source.checkedQuantityAs!(Spec,Unit,T));
}
@safe pure nothrow @nogc
Observation kernel(T,Spec,Unit,bool rounded,S)(S source)
{
    static if(is(T==long))
    {
        const r=convertFloatingLong(source,Unit.Scale.numerator,Unit.Scale.denominator,
            Spec.CanonicalUnit.Scale.numerator,Spec.CanonicalUnit.Scale.denominator,
            rounded,IntegralRoundingMode.floor);
        return Observation(mapped(r.status),r.hasValue,r.hasValue?cast(ulong)r.value:0UL);
    }
    else
    {
        const r=composedFloating!T(source,Unit.Scale.numerator,Unit.Scale.denominator,
            Spec.CanonicalUnit.Scale.numerator,Spec.CanonicalUnit.Scale.denominator);
        const present=r.status==Status.exact || r.status==Status.inexact;
        return Observation(mapped(r.status),present,present?storedBits(r.value):0UL);
    }
}

S sample(S)(size_t i)
{
    static if(is(S==ulong)) return ulong.max-cast(ulong)i*1024UL;
    else static if(is(S==float))
    {
        enum ulong[8] edges=[0,1,0x80000000,0x7f7fffff,0xff7fffff,0x7f800000,0x7fc00001,0x00800000];
        if(i<edges.length) return fromBits!float(edges[i]);
        return fromBits!float(0x3f800000UL|((i*2654435761UL)&0x7fffffUL)|((i&1UL)<<31));
    }
    else static if(is(S==double))
    {
        enum ulong[8] edges=[0,1,1UL<<63,0x7fefffffffffffffUL,0xffefffffffffffffUL,
            0x7ff0000000000000UL,0x7ff8000000000001UL,0x0010000000000000UL];
        if(i<edges.length) return fromBits!double(edges[i]);
        return fromBits!double(0x3ff0000000000000UL|((i*11400714819323198485UL)&0xfffffffffffffUL)|((i&1UL)<<63));
    }
    else
    {
        const sig=(1UL<<63)|cast(ulong)i*11400714819323198485UL;
        const value=ldexp(cast(real)sig,-63);
        return i&1 ? -value : value;
    }
}

ulong mix(ulong state,Observation o) @safe pure nothrow @nogc
{
    return (state^o.bits^(cast(ulong)o.status<<3)^cast(ulong)o.present)*1099511628211UL;
}
__gshared ulong sink;
pragma(inline,false)
ulong loop(bool publicAPI,T,Spec,Unit,bool rounded,S)(S[] input)
{
    ulong hash=1469598103934665603UL;
    foreach(value;input)
    {
        static if(publicAPI) const o=api!(T,Spec,Unit,rounded)(value);
        else const o=kernel!(T,Spec,Unit,rounded)(value);
        hash=mix(hash,o);
    }
    sink=hash;
    return hash;
}
long timed(bool publicAPI,T,Spec,Unit,bool rounded,S)(S[] input,ulong expected)
{
    StopWatch sw;
    sw.start();
    const hash=loop!(publicAPI,T,Spec,Unit,rounded)(input);
    sw.stop();
    if(hash!=expected) throw new Exception("benchmark checksum changed");
    return sw.peek.total!"nsecs";
}
void measure(T,Spec,Unit,bool rounded,S)(string name)
{
    enum count=8192,rounds=7;
    S[count] input;
    foreach(i,ref value;input) value=sample!S(i);
    foreach(value;input)
        if(api!(T,Spec,Unit,rounded)(value)!=kernel!(T,Spec,Unit,rounded)(value))
            throw new Exception("API/kernel semantic mismatch");
    const expected=loop!(true,T,Spec,Unit,rounded)(input[]);
    if(loop!(false,T,Spec,Unit,rounded)(input[])!=expected)
        throw new Exception("warmup mismatch");
    long[rounds] a,b;
    foreach(i;0..rounds)
    {
        if(i&1)
        {
            b[i]=timed!(false,T,Spec,Unit,rounded)(input[],expected);
            a[i]=timed!(true,T,Spec,Unit,rounded)(input[],expected);
        }
        else
        {
            a[i]=timed!(true,T,Spec,Unit,rounded)(input[],expected);
            b[i]=timed!(false,T,Spec,Unit,rounded)(input[],expected);
        }
    }
    sort(a[]); sort(b[]);
    writefln("INTEGRAL_IDENTITY_COST,%s,%.2f,%.2f,%.3f,%.2f,%.2f,%.2f,%.2f,%s",
        name,cast(double)a[rounds/2]/count,cast(double)b[rounds/2]/count,
        cast(double)a[rounds/2]/b[rounds/2],cast(double)a[0]/count,
        cast(double)a[$-1]/count,cast(double)b[0]/count,cast(double)b[$-1]/count,expected);
}
void main()
{
    if(r15FloatLong(1F)!=r15BaselineFloatLong(1F) ||
        r15DoubleLong(1.0)!=r15BaselineDoubleLong(1.0) ||
        r15DoubleLongFloor(-1.5)!=r15BaselineDoubleLongFloor(-1.5))
        throw new Exception("codegen wrapper sanity gate failed");
    writeln("INTEGRAL_IDENTITY_COST_HEADER,case,api_median_ns,kernel_median_ns,ratio,api_min_ns,api_max_ns,kernel_min_ns,kernel_max_ns,checksum");
    measure!(float,Length,Metre,false,float)("float_float_identity");
    measure!(double,Length,Metre,false,double)("double_double_identity");
    measure!(float,Length,Metre,false,double)("double_float_identity");
    measure!(float,Length,DirectRoundingUnit,false,double)("double_float_direct_rounding");
    measure!(double,Length,InternationalFoot,false,double)("double_double_foot");
    measure!(double,WideSpec,WideFrom,false,double)("double_double_wide_composed");
    measure!(double,Length,Metre,false,ulong)("ulong_double_identity");
    measure!(double,Length,Metre,false,float)("float_double_identity");
    measure!(long,Length,Metre,false,float)("float_long_checked");
    measure!(long,Length,Metre,true,float)("float_long_floor_identity");
    measure!(long,Length,Metre,true,double)("double_long_floor_identity");
    static if(qualifiedReal)
    {
        measure!(long,Length,Metre,false,real)("real_long_checked");
        measure!(long,Length,Metre,true,real)("real_long_floor_identity");
    }
    measure!(long,Length,Metre,false,double)("double_long_checked");
    measure!(long,Length,InternationalFoot,true,double)("double_long_floor_foot");
    static if(qualifiedReal)
        measure!(double,WideSpec,WideFrom,false,real)("real_double_wide_composed");
    writeln("R15 Probe 19 COST PASS: per-input API/kernel equality and timed checksums; 8192 inputs, 7 alternating rounds");
}
