module r15_composed_kernel;

import r15_rescale_kernel : Result, Status, fromBits;

private:
// Private research carrier. Little-endian base-2^32 limbs; no public Rep.
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

public:
void composedWidths(ulong sig,long fn,long fd,long tn,long td,
    out int numeratorBits,out int denominatorBits) @safe pure nothrow @nogc
{
    const ratio=compose(sig,false,fn,fd,tn,td);
    numeratorBits=bitLength(ratio.numerator);
    denominatorBits=bitLength(ratio.denominator);
}

Result!T convertComposedExact(T)(ulong significand,int exponent2,bool negative,
    long fromNumerator,long fromDenominator,long toNumerator,long toDenominator)
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
{
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


