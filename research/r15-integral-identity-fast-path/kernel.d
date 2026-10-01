module r15_integral_identity_kernel;

import r15_composed_kernel : IntegralResult, IntegralRoundingMode;
import r15_rescale_kernel : Status, storedBits;
import std.traits : Unqual;
import std.math : frexp, ldexp;

import r15_floating_integral_kernel : convertFloatingLong, qualifiedReal;

// Closed identity domain, with the historical composed kernel as fallback.
IntegralResult identityOrComposedLong(From,To,S)(S value,
    bool rounded, IntegralRoundingMode mode) @safe pure nothrow @nogc
    if (is(Unqual!S == float) || is(Unqual!S == double) ||
        (is(Unqual!S == real) && qualifiedReal))
{
    static if (From.Scale.numerator != To.Scale.numerator ||
               From.Scale.denominator != To.Scale.denominator)
        return convertFloatingLong(value,From.Scale.numerator,From.Scale.denominator,
            To.Scale.numerator,To.Scale.denominator,rounded,mode);
    else
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
            return identityLong(0,0,false,rounded,mode);
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
    return identityLong(sig,exponent2,negative,rounded,mode);
    }
}

// Research tuple entry point; exact magnitude is sig * 2^^exponent2.
// The unsigned left/right-shift branches never shift by 64 or more.
IntegralResult identityLong(ulong sig,int exponent2,bool negative,bool rounded,
    IntegralRoundingMode mode) @safe pure nothrow @nogc
{
    if (sig == 0) return IntegralResult(Status.exact,true,0);
    const bound = cast(ulong)long.max + (negative ? 1UL : 0UL);
    ulong magnitude, remainder;
    bool fractional;
    long shift;
    if (exponent2 >= 0)
    {
        if (exponent2 >= 64 || sig > (bound >> exponent2))
            return IntegralResult(Status.overflow,false,0);
        magnitude = sig << exponent2;
    }
    else
    {
        shift = -cast(long)exponent2;
        if (shift >= 64) { magnitude=0; fractional=true; }
        else
        {
            magnitude = sig >> shift;
            remainder = sig & ((1UL << shift)-1UL);
            fractional = remainder != 0;
        }
        // Reject the exact rational outside the closed long range BEFORE rounding.
        if (magnitude > bound || (magnitude == bound && fractional))
            return IntegralResult(Status.overflow,false,0);
    }
    if (fractional && !rounded) return IntegralResult(Status.inexact,false,0);
    if (fractional)
    {
        bool increment;
        final switch (mode)
        {
            case IntegralRoundingMode.towardZero: break;
            case IntegralRoundingMode.floor: increment=negative; break;
            case IntegralRoundingMode.ceiling: increment=!negative; break;
            case IntegralRoundingMode.nearestTiesAway:
                if (shift == 64) increment = sig >= (1UL << 63);
                else if (shift < 64) increment = remainder >= (1UL << (shift-1));
                break;
        }
        if (increment) ++magnitude;
    }
    // Integer endpoints imply every supported rounded result remains in range.
    const value = negative ? (magnitude == (1UL << 63) ? long.min : -cast(long)magnitude)
                          : cast(long)magnitude;
    return IntegralResult(fractional ? Status.inexact : Status.exact,true,value);
}
