module r15_integral_source_kernel;
import std.traits : Unqual;
import r15_composed_kernel : IntegralResult,IntegralRoundingMode,convertComposedLong;
import r15_rescale_kernel : Status;

enum integralSource(S)=is(Unqual!S==long) || is(Unqual!S==ulong);

IntegralResult integralLong(From,To,S)(S value,bool rounded,IntegralRoundingMode mode)
    @safe pure nothrow @nogc if(integralSource!S)
{
    static if(From.Scale.numerator==To.Scale.numerator &&
              From.Scale.denominator==To.Scale.denominator)
    {
        static if(is(Unqual!S==ulong))
            if(value>cast(ulong)long.max) return IntegralResult(Status.overflow,false,0);
        return IntegralResult(Status.exact,true,cast(long)value);
    }
    else
    {
        bool negative;
        ulong magnitude;
        static if(is(Unqual!S==long))
        {
            negative=value<0;
            magnitude=negative ? cast(ulong)(-(value+1))+1UL : cast(ulong)value;
        }
        else magnitude=value;
        return convertComposedLong(magnitude,0,negative,From.Scale.numerator,
            From.Scale.denominator,To.Scale.numerator,To.Scale.denominator,rounded,mode);
    }
}
