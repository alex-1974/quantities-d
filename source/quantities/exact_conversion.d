module quantities.exact_conversion;

// Selective promotion of the qualified R15 composed-ratio algorithm.
// Existing arithmetic quantizers have different range/status contracts; they
// remain unchanged. This module does not import the research tree.
import core.stdc.string : memcpy;
import quantities.conversion : ConversionStatus, RoundingMode;
import quantities.real_scale : supportsExactRealRescale;
import std.math : frexp, ldexp;
import std.traits : Unqual;

package(quantities):
alias Status = ConversionStatus;
alias IntegralRoundingMode = RoundingMode;
alias qualifiedReal = supportsExactRealRescale;

struct Result(T)
{
    Status status;
    T value;
}

enum supportedSource(S) = is(Unqual!S == long) || is(Unqual!S == ulong) ||
    is(Unqual!S == float) || is(Unqual!S == double) ||
    (is(Unqual!S == real) && qualifiedReal);

// Copies exactly sizeof(T) bytes between equally sized scalar objects. The
// local objects cannot alias, and no pointer escapes the trusted boundary.
ulong storedBits(T)(T value) @safe pure nothrow @nogc
    if (is(Unqual!T == float) || is(Unqual!T == double))
{
    static if (is(Unqual!T == float))
    {
        uint bits;
        () @trusted { memcpy(&bits, &value, uint.sizeof); }();
        return bits;
    }
    else
    {
        ulong bits;
        () @trusted { memcpy(&bits, &value, ulong.sizeof); }();
        return bits;
    }
}

T fromBits(T)(ulong bits) @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
{
    T value;
    static if (is(T == float))
    {
        const uint raw = cast(uint)bits;
        () @trusted { memcpy(&value, &raw, uint.sizeof); }();
    }
    else
        () @trusted { memcpy(&value, &bits, ulong.sizeof); }();
    return value;
}

private:
// Little-endian base-2^32 limbs, independent of machine byte order.
// Conversion-only workspace; never a quantity Rep.
struct Wide { uint[6] limbs; }

int bitLength(Wide x) @safe pure nothrow @nogc
{
    foreach_reverse (i; 0 .. 6)
    {
        if (x.limbs[i] == 0) continue;
        uint v = x.limbs[i];
        int bits;
        while (v != 0) { ++bits; v >>= 1; }
        return cast(int)i * 32 + bits;
    }
    return 0;
}

Wide fromUlong(ulong x) @safe pure nothrow @nogc
{
    Wide w;
    w.limbs[0] = cast(uint)x;
    w.limbs[1] = cast(uint)(x >> 32);
    return w;
}

int compare(Wide a, Wide b) @safe pure nothrow @nogc
{
    foreach_reverse (i; 0 .. 6)
    {
        if (a.limbs[i] < b.limbs[i]) return -1;
        if (a.limbs[i] > b.limbs[i]) return 1;
    }
    return 0;
}

Wide subtract(Wide a, Wide b) @safe pure nothrow @nogc
{
    assert(compare(a,b) >= 0);
    ulong borrow;
    Wide result;
    foreach (i; 0 .. 6)
    {
        const sub = cast(ulong)b.limbs[i] + borrow;
        const av = cast(ulong)a.limbs[i];
        result.limbs[i] = cast(uint)(av - sub);
        borrow = av < sub ? 1UL : 0UL;
    }
    assert(borrow == 0);
    return result;
}

Wide shiftLeft(Wide x, int count) @safe pure nothrow @nogc
{
    assert(count >= 0);
    foreach (_; 0 .. count)
    {
        assert((x.limbs[5] & 0x80000000U) == 0);
        uint carry;
        foreach (i; 0 .. 6)
        {
            const next = x.limbs[i] >> 31;
            x.limbs[i] = (x.limbs[i] << 1) | carry;
            carry = next;
        }
    }
    return x;
}

Wide multiplySmall(Wide a, ulong b) @safe pure nothrow @nogc
{
    uint[8] result;
    const uint[2] digits = [cast(uint)b,cast(uint)(b >> 32)];
    foreach (i; 0 .. 6)
    {
        ulong carry;
        foreach (j; 0 .. 2)
        {
            // (B-1)^2 + 2*(B-1) == 2^64-1 for B=2^32.
            const sum = cast(ulong)a.limbs[i] * digits[j]
                + result[i+j] + carry;
            result[i+j] = cast(uint)sum;
            carry = sum >> 32;
        }
        int k = i+2;
        while (carry != 0)
        {
            assert(k < 8);
            const sum = cast(ulong)result[k] + carry;
            result[k] = cast(uint)sum;
            carry = sum >> 32;
            ++k;
        }
    }
    assert(result[6] == 0 && result[7] == 0);
    Wide outValue;
    outValue.limbs[] = result[0 .. 6];
    return outValue;
}

ulong magnitude(long x) @safe pure nothrow @nogc
{
    return x < 0 ? cast(ulong)(-(x+1)) + 1UL : cast(ulong)x;
}

void cancel(ref ulong a, ref ulong b) @safe pure nothrow @nogc
{
    ulong x = a, y = b;
    while (y != 0) { const r=x%y; x=y; y=r; }
    if (x > 1) { a/=x; b/=x; }
}
private struct NormalizedRatio
{
    Wide numerator;
    Wide denominator;
    int exponent2;
}

private NormalizedRatio normalize(
    Wide numerator,
    Wide denominator)
    @safe pure nothrow @nogc
{
    assert(bitLength(numerator) != 0);
    assert(bitLength(denominator) != 0);

    int exponent2 =
        bitLength(numerator)
        - bitLength(denominator);

    Wide a;
    Wide b;

    if (exponent2 >= 0)
    {
        a = numerator;
        b = shiftLeft(denominator, exponent2);
    }
    else
    {
        a = shiftLeft(numerator, -exponent2);
        b = denominator;
    }

    if (compare(a, b) < 0)
    {
        --exponent2;

        if (exponent2 >= 0)
        {
            a = numerator;
            b = shiftLeft(denominator, exponent2);
        }
        else
        {
            a = shiftLeft(numerator, -exponent2);
            b = denominator;
        }
    }

    assert(compare(a, b) >= 0);
    return NormalizedRatio(a, b, exponent2);
}

private int compareScaled(Wide a, int ae, Wide b, int be)
    @safe pure nothrow @nogc
{
    const ab = bitLength(a);
    const bb = bitLength(b);
    if (ab + ae != bb + be)
        return ab + ae < bb + be ? -1 : 1;
    if (ae < be)
        return compare(a, shiftLeft(b, be - ae));
    return compare(shiftLeft(a, ae - be), b);
}

private ulong roundedSignificand(
    Wide a, Wide b, int fractionBits, out bool exact)
    @safe pure nothrow @nogc
{
    assert(fractionBits >= 0 && fractionBits <= 52);
    ulong result = 1UL << fractionBits;
    Wide remainder = subtract(a, b);
    foreach (i; 0 .. fractionBits)
    {
        remainder = shiftLeft(remainder, 1);
        if (compare(remainder, b) >= 0)
        {
            result |= 1UL << (fractionBits - 1 - i);
            remainder = subtract(remainder, b);
        }
    }
    exact = bitLength(remainder) == 0;
    const cmp = compare(shiftLeft(remainder, 1), b);
    if (cmp > 0 || (cmp == 0 && (result & 1) != 0))
        ++result;
    return result;
}


private struct Composed
{
    Wide numerator;
    Wide denominator;
    bool negative;
}

private Composed compose(ulong significand, bool negative,
    long fromNumerator, long fromDenominator,
    long toNumerator, long toDenominator) @safe pure nothrow @nogc
{
    assert(fromNumerator != 0 && toNumerator != 0);
    assert(fromDenominator > 0 && toDenominator > 0);
    ulong[3] ns = [significand,magnitude(fromNumerator),cast(ulong)toDenominator];
    ulong[2] ds = [cast(ulong)fromDenominator,magnitude(toNumerator)];
    foreach (ref n; ns)
        foreach (ref d; ds)
            cancel(n,d);
    auto a = fromUlong(ns[0]);
    a = multiplySmall(a,ns[1]);
    a = multiplySmall(a,ns[2]);
    const b = multiplySmall(fromUlong(ds[0]),ds[1]);
    assert(bitLength(a) <= 190 && bitLength(b) <= 126);
    return Composed(a,b,(negative != (fromNumerator < 0)) != (toNumerator < 0));
}

package(quantities):
// Internal observation only. Public carriers are constructed by the API layer.
struct IntegralResult
{
    Status status;
    bool hasValue;
    long value;
}

IntegralResult convertComposedLong(ulong significand, int exponent2, bool negative,
    long fn, long fd, long tn, long td, bool rounded, IntegralRoundingMode mode)
    @safe pure nothrow @nogc
{
    // Covers all qualified source formats without unbounded exponent arithmetic.
    assert(exponent2 >= -16445 && exponent2 <= 16383);
    const r = compose(significand, negative, fn, fd, tn, td);
    if (significand == 0)
        return IntegralResult(Status.exact, true, 0);
    const bound = cast(ulong)long.max + (r.negative ? 1UL : 0UL);
    if (compareScaled(r.numerator, exponent2,
        multiplySmall(r.denominator, bound), 0) > 0)
        return IntegralResult(Status.overflow, false, 0);

    // Find floor of magnitude. Every denominator*trial fits <=189 bits.
    // Avoid shifting the separated exponent into a potentially huge integer.
    ulong low = 0, high = bound;
    while (low < high)
    {
        const distance = high - low;
        const trial = low + distance / 2 + distance % 2;
        if (compareScaled(r.numerator, exponent2,
            multiplySmall(r.denominator, trial), 0) >= 0)
            low = trial;
        else
            high = trial - 1;
    }
    const exact = low != 0 && compareScaled(r.numerator, exponent2,
        multiplySmall(r.denominator, low), 0) == 0;
    if (!exact && !rounded)
        return IntegralResult(Status.inexact, false, 0);
    if (!exact)
    {
        bool increment;
        final switch (mode)
        {
            case IntegralRoundingMode.towardZero: break;
            case IntegralRoundingMode.floor: increment = r.negative; break;
            case IntegralRoundingMode.ceiling: increment = !r.negative; break;
            case IntegralRoundingMode.nearestTiesAway:
                // Inexact, in-range => low < bound, hence 2*low+1 fits ulong.
                increment = compareScaled(r.numerator, exponent2 + 1,
                    multiplySmall(r.denominator, low * 2UL + 1UL), 0) >= 0;
                break;
        }
        if (increment) ++low;
    }
    assert(low <= bound);
    const value = r.negative
        ? (low == (1UL << 63) ? long.min : -cast(long)low)
        : cast(long)low;
    return IntegralResult(exact ? Status.exact : Status.inexact, true, value);
}

Result!T convertComposedExact(T)(ulong significand,int exponent2,bool negative,
    long fromNumerator,long fromDenominator,long toNumerator,long toDenominator)
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
{
    assert(exponent2 >= -16445 && exponent2 <= 16383);
    enum p = is(T == float) ? 24 : 53;
    enum emin = is(T == float) ? -126 : -1022;
    enum emax = is(T == float) ? 127 : 1023;
    enum sub = emin - (p - 1);
    enum bias = is(T == float) ? 127 : 1023;
    enum signShift = is(T == float) ? 31 : 63;
    const composed = compose(significand,negative,
        fromNumerator,fromDenominator,toNumerator,toDenominator);
    const sign = composed.negative ? 1UL << signShift : 0UL;
    if (significand == 0)
        return Result!T(Status.exact,fromBits!T(sign));
    const a=composed.numerator;
    const b=composed.denominator;
    const maxBound=multiplySmall(b,(1UL << p)-1UL);
    if (compareScaled(a,exponent2,maxBound,emax-(p-1)) > 0)
        return Result!T(Status.overflow,T.init);

    const r = normalize(a, b);
    int e = exponent2 + r.exponent2;
    bool exact;
    ulong bits;
    if (e >= emin)
    {
        ulong sig = roundedSignificand(r.numerator, r.denominator, p - 1, exact);
        if (sig == (1UL << p))
        {
            sig >>= 1;
            ++e;
        }
        bits = (cast(ulong)(e + bias) << (p - 1)) | (sig - (1UL << (p - 1)));
    }
    else
    {
        const power = e - sub;
        if (power < -1)
            bits = 0;
        else if (power == -1)
            bits = compare(r.numerator, r.denominator) == 0 ? 0UL : 1UL;
        else
            bits = roundedSignificand(r.numerator, r.denominator, power, exact);
        // Subnormal quanta also encode the carry into the minimum normal.
    }
    return Result!T(exact ? Status.exact : Status.inexact, fromBits!T(sign | bits));
}


private struct SourceTuple
{
    ulong significand;
    int exponent2;
    bool negative;
    bool nonFinite;
}

private SourceTuple representedSource(S)(S value)
    @safe pure nothrow @nogc if (supportedSource!S)
{
    SourceTuple result;
    static if (is(Unqual!S == long))
    {
        result.negative = value < 0;
        result.significand = magnitude(value);
    }
    else static if (is(Unqual!S == ulong)) result.significand = value;
    else
    {
        if (__ctfe)
            assert(false, "quantities-d: represented floating conversion requires runtime");
        static if (is(Unqual!S == float) || is(Unqual!S == double))
        {
            enum p = is(Unqual!S == float) ? 24 : 53;
            enum expBits = is(Unqual!S == float) ? 8 : 11;
            enum bias = is(Unqual!S == float) ? 127 : 1023;
            enum signShift = is(Unqual!S == float) ? 31 : 63;
            const raw = storedBits(value);
            const ef = (raw >> (p - 1)) & ((1UL << expBits) - 1UL);
            result.nonFinite = ef == ((1UL << expBits) - 1UL);
            const fraction = raw & ((1UL << (p - 1)) - 1UL);
            result.significand = ef == 0 ? fraction : fraction | (1UL << (p - 1));
            result.exponent2 = ef == 0 ? 1 - bias - (p - 1) : cast(int)ef - bias - (p - 1);
            result.negative = (raw >> signShift) != 0;
        }
        else
        {
            result.nonFinite = value != value || value > real.max || value < -real.max;
            if (result.nonFinite) return result;
            if (value == 0) result.negative = 1.0L / value < 0;
            else
            {
                result.negative = value < 0;
                int e;
                const fraction = frexp(result.negative ? -value : value, e);
                result.significand = cast(ulong)ldexp(fraction, real.mant_dig);
                result.exponent2 = e - real.mant_dig;
                // Strip redundant frexp bits so binary80 minSubnormal uses
                // exponent -16445 rather than -16508. Value stays exact.
                while ((result.significand & 1UL) == 0)
                {
                    result.significand >>= 1;
                    ++result.exponent2;
                }
            }
        }
    }
    return result;
}

package(quantities):
IntegralResult convertIntegral(S)(S value, long fn, long fd, long tn, long td,
    bool rounded, RoundingMode mode) @safe pure nothrow @nogc
    if (supportedSource!S)
{
    const source = representedSource(value);
    if (source.nonFinite) return IntegralResult(Status.nonFinite, false, 0);
    return convertComposedLong(source.significand, source.exponent2,
        source.negative, fn, fd, tn, td, rounded, mode);
}

Result!T convertFloating(T, S)(S value, long fn, long fd, long tn, long td)
    @safe pure nothrow @nogc
    if ((is(T == float) || is(T == double)) && supportedSource!S)
{
    if (__ctfe)
        assert(false, "quantities-d: floating target conversion requires runtime");
    const source = representedSource(value);
    if (source.nonFinite) return Result!T(Status.nonFinite, T.init);
    return convertComposedExact!T(source.significand, source.exponent2,
        source.negative, fn, fd, tn, td);
}

@safe unittest
{
    // The integral path remains CTFE capable, including full-width magnitude.
    enum min = convertIntegral(long.min, 1, 1, 1, 1, false, RoundingMode.towardZero);
    static assert(min.status == Status.exact && min.hasValue && min.value == long.min);
    enum wide = convertIntegral(ulong.max, 1, 1, 2, 1, true, RoundingMode.towardZero);
    static assert(wide.status == Status.overflow && !wide.hasValue);
    enum half = convertIntegral(3L, 1, 2, 1, 1, true, RoundingMode.nearestTiesAway);
    static assert(half.status == Status.inexact && half.hasValue && half.value == 2);
    static assert(!__traits(compiles, convertIntegral(1,1,1,1,1,false,RoundingMode.floor)));
    static assert(!__traits(compiles, convertFloating!real(1L,1,1,1,1)));
    static assert(!__traits(compiles, { enum r = convertIntegral(1.0,1,1,1,1,false,RoundingMode.floor); }));
    static assert(!__traits(compiles, { enum r = convertFloating!float(1L,1,1,1,1); }));
    static if (qualifiedReal)
        static assert(!__traits(compiles, { enum r = convertIntegral(1.0L,1,1,1,1,false,RoundingMode.floor); }));
    () @safe pure nothrow @nogc {
        const r = convertIntegral(-1.5,1,1,1,1,true,RoundingMode.floor);
        assert(r.status == Status.inexact && r.hasValue && r.value == -2);
        const f = convertFloating!float(ulong.max,1,1,1,1);
        assert(f.status == Status.inexact && f.value == 0x1p64F);
        const z = convertFloating!double(-0.0, -1,1,1,1);
        assert(z.status == Status.exact && storedBits(z.value) == 0);
        const overflow = convertComposedLong(ulong.max,-1,false,1,1,1,1,true,RoundingMode.towardZero);
        assert(overflow.status == Status.overflow && !overflow.hasValue);
        const nonFinite = convertFloating!float(double.infinity,1,1,1,1);
        assert(nonFinite.status == Status.nonFinite);
    }();
}
