module r15_identity_kernel;
import r15_floating_target_kernel : composedFloating,supportedSource;
import r15_rescale_kernel : Result,Status,storedBits,fromBits;
import std.traits : Unqual;
import core.bitop : bsr;

enum identityInclusion(T,From,To,S) =
    From.Scale.numerator==To.Scale.numerator &&
    From.Scale.denominator==To.Scale.denominator &&
    ((is(Unqual!S==float) && (is(T==float) || is(T==double))) ||
     (is(Unqual!S==double) && is(T==double)));

Result!T identityOrComposed(T,From,To,S)(S value)
    @safe pure nothrow @nogc
    if((is(T==float) || is(T==double)) && supportedSource!S)
{
    static if(identityInclusion!(T,From,To,S))
    {
        const raw=storedBits(value); // Retains the runtime represented-source CTFE boundary.
        static if(is(Unqual!S==double))
        {
            if(((raw>>52)&0x7ffUL)==0x7ffUL) return Result!T(Status.nonFinite,T.init);
            return Result!T(Status.exact,fromBits!T(raw));
        }
        else
        {
            const ef=(raw>>23)&0xffUL;
            if(ef==0xffUL) return Result!T(Status.nonFinite,T.init);
            static if(is(T==float)) return Result!T(Status.exact,fromBits!T(raw));
            else
            {
                // Exact binary32 -> binary64 embedding, including every subnormal.
                // Integer bit construction avoids ambient FP rounding/denormal modes.
                const sign=(raw>>31)<<63;
                const fraction=raw&0x7fffffUL;
                ulong bits=sign;
                if(ef!=0) bits|=((ef+896UL)<<52)|(fraction<<29);
                else if(fraction!=0)
                {
                    const top=bsr(fraction); // Nonzero precondition is explicit.
                    bits|=(cast(ulong)(top+874)<<52)|
                        ((fraction-(1UL<<top))<<(52-top));
                }
                return Result!T(Status.exact,fromBits!T(bits));
            }
        }
    }
    else return composedFloating!T(value,
        From.Scale.numerator,From.Scale.denominator,
        To.Scale.numerator,To.Scale.denominator);
}
