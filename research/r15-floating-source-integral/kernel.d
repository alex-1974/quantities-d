module r15_floating_integral_kernel;

import r15_composed_kernel : IntegralResult, IntegralRoundingMode, convertComposedLong;
import r15_rescale_kernel : Status, storedBits;
import std.traits : Unqual;
import std.math : frexp, ldexp;

enum qualifiedReal =
    (real.mant_dig == 64 && real.min_exp == -16381 && real.max_exp == 16384) ||
    (real.mant_dig == 53 && real.min_exp == -1021 && real.max_exp == 1024);

// Research wrapper: S is deduced, target is fixed long, intent is explicit.
IntegralResult convertFloatingLong(S)(S value,
    long fn, long fd, long tn, long td, bool rounded, IntegralRoundingMode mode)
    @safe pure nothrow @nogc
    if (is(Unqual!S == float) || is(Unqual!S == double) ||
        (is(Unqual!S == real) && qualifiedReal))
{
    ulong sig;
    int exponent2;
    bool negative;
    static if (is(Unqual!S == float) || is(Unqual!S == double))
    {
        enum p = is(Unqual!S == float) ? 24 : 53;
        enum expBits = is(Unqual!S == float) ? 8 : 11;
        enum bias = is(Unqual!S == float) ? 127 : 1023;
        enum signShift = is(Unqual!S == float) ? 31 : 63;
        const raw = storedBits(value);
        const ef = (raw >> (p-1)) & ((1UL << expBits)-1UL);
        if (ef == ((1UL << expBits)-1UL))
            return IntegralResult(Status.nonFinite, false, 0);
        const fraction = raw & ((1UL << (p-1))-1UL);
        sig = ef == 0 ? fraction : fraction | (1UL << (p-1));
        exponent2 = ef == 0 ? 1-bias-(p-1) : cast(int)ef-bias-(p-1);
        negative = (raw >> signShift) != 0;
    }
    else
    {
        if (value != value || value > real.max || value < -real.max)
            return IntegralResult(Status.nonFinite, false, 0);
        if (value == 0)
            return convertComposedLong(0,0,false,fn,fd,tn,td,rounded,mode);
        negative = value < 0;
        int e;
        const f = frexp(negative ? -value : value, e);
        sig = cast(ulong)ldexp(f, real.mant_dig);
        exponent2 = e-real.mant_dig;
        // frexp normalizes subnormals: a 64-bit tuple for real80 minSubnormal
        // has exponent -16508. Remove redundant zero bits before the bounded
        // integral tuple kernel, preserving the exact represented value.
        while ((sig & 1UL) == 0)
        {
            sig >>= 1;
            ++exponent2;
        }
    }
    return convertComposedLong(sig,exponent2,negative,fn,fd,tn,td,rounded,mode);
}
