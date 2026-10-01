module r15_floating_target_kernel;
import r15_composed_kernel : convertComposedExact;
import r15_rescale_kernel : Result, Status, storedBits;
import r15_floating_integral_kernel : qualifiedReal;
import std.traits : Unqual;
import std.math : frexp, ldexp;

enum supportedSource(S) = is(Unqual!S == long) || is(Unqual!S == ulong) ||
    is(Unqual!S == float) || is(Unqual!S == double) ||
    (is(Unqual!S == real) && qualifiedReal);

Result!T composedFloating(T,S)(S value,long fn,long fd,long tn,long td)
    @safe pure nothrow @nogc
    if ((is(T == float) || is(T == double)) && supportedSource!S)
{
    ulong sig;
    int exponent2;
    bool negative;
    static if (is(Unqual!S == long))
    {
        negative = value < 0;
        sig = negative ? cast(ulong)(-(value+1)) + 1UL : cast(ulong)value;
    }
    else static if (is(Unqual!S == ulong)) sig = value;
    else static if (is(Unqual!S == float) || is(Unqual!S == double))
    {
        enum p = is(Unqual!S == float) ? 24 : 53;
        enum expBits = is(Unqual!S == float) ? 8 : 11;
        enum bias = is(Unqual!S == float) ? 127 : 1023;
        enum signShift = is(Unqual!S == float) ? 31 : 63;
        const raw = storedBits(value);
        const ef = (raw >> (p-1)) & ((1UL << expBits)-1UL);
        if (ef == ((1UL << expBits)-1UL)) return Result!T(Status.nonFinite,T.init);
        const fraction = raw & ((1UL << (p-1))-1UL);
        sig = ef == 0 ? fraction : fraction | (1UL << (p-1));
        exponent2 = ef == 0 ? 1-bias-(p-1) : cast(int)ef-bias-(p-1);
        negative = (raw >> signShift) != 0;
    }
    else
    {
        if (value != value || value > real.max || value < -real.max)
            return Result!T(Status.nonFinite,T.init);
        if (value == 0) negative = 1.0L/value < 0;
        else
        {
            negative = value < 0;
            int e;
            const f = frexp(negative ? -value : value,e);
            sig = cast(ulong)ldexp(f,real.mant_dig);
            exponent2 = e-real.mant_dig;
            while ((sig & 1UL) == 0) { sig >>= 1; ++exponent2; }
        }
    }
    return convertComposedExact!T(sig,exponent2,negative,fn,fd,tn,td);
}
