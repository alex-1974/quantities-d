module quantities.binary64_scale;

import core.int128 : Cent, mul, udivmod;
import core.stdc.string : memcpy;
import std.math : ldexp;

struct Binary64ScaleResult
{
    double value;
    bool overflow;
}

private:
struct Binary64Exact
{
    bool negative;
    ulong significand;
    int exponent2;
}

struct RoundedRational
{
    ulong significand;
    int exponent2;
    bool overflow;
}


@safe pure nothrow @nogc
ulong gcd(ulong a, ulong b)
{
    while (b != 0)
    {
        const r = a % b;
        a = b;
        b = r;
    }
    return a;
}

@safe pure nothrow @nogc
ulong binary64Bits(double value)
{
    ulong bits;

    () @trusted {
        memcpy(&bits, &value, double.sizeof);
    }();

    return bits;
}

@safe pure nothrow @nogc
Binary64Exact decompose(double value)
{
    const bits = binary64Bits(value);
    const negative = (bits >> 63) != 0;
    const exponentField = cast(uint)((bits >> 52) & 0x7ffUL);
    const fraction = bits & ((1UL << 52) - 1UL);

    if (exponentField == 0)
    {
        // Zero or subnormal: fraction * 2^-1074.
        return Binary64Exact(negative, fraction, -1074);
    }

    // scaleBinary64 is called only for finite values.
    assert(exponentField != 0x7ff);

    // Normal:
    //   (2^52 + fraction) * 2^(biasedExponent - 1023 - 52)
    return Binary64Exact(
        negative,
        (1UL << 52) | fraction,
        cast(int) exponentField - 1023 - 52);
}

@safe pure nothrow @nogc
int bitLength(ulong value)
{
    int bits;
    while (value != 0)
    {
        ++bits;
        value >>= 1;
    }
    return bits;
}

@safe pure nothrow @nogc
Cent fromUlong128(ulong value)
{
    return Cent(value, 0);
}

@safe pure nothrow @nogc
bool centIsZero(Cent value)
{
    return value.lo == 0 && value.hi == 0;
}

@safe pure nothrow @nogc
bool centGreater(Cent a, Cent b)
{
    return a.hi > b.hi || (a.hi == b.hi && a.lo > b.lo);
}

@safe pure nothrow @nogc
bool centEqual(Cent a, Cent b)
{
    return a.hi == b.hi && a.lo == b.lo;
}

@safe pure nothrow @nogc
ulong roundCentQuotientNearestEven(
    Cent numerator,
    ulong denominator)
{
    Cent remainder;
    const quotient =
        udivmod(numerator, fromUlong128(denominator), remainder);

    assert(quotient.hi == 0);
    ulong q = quotient.lo;

    if (centIsZero(remainder))
        return q;

    const doubledRemainder = mul(remainder, fromUlong128(2));
    const denominator128 = fromUlong128(denominator);

    if (centGreater(doubledRemainder, denominator128)
        || (centEqual(doubledRemainder, denominator128)
            && (q & 1UL) != 0))
    {
        ++q;
    }

    return q;
}

@safe pure nothrow @nogc
int centBitLength(Cent value)
{
    if (value.hi != 0)
        return 64 + bitLength(value.hi);
    return bitLength(value.lo);
}

@safe pure nothrow @nogc
Cent shlCent(Cent value, int shift, out bool overflow)
{
    overflow = false;

    foreach (_; 0 .. shift)
    {
        if ((value.hi & (1UL << 63)) != 0)
        {
            overflow = true;
            return value;
        }

        value.hi = (value.hi << 1) | (value.lo >> 63);
        value.lo <<= 1;
    }

    return value;
}

@safe pure nothrow @nogc
RoundedRational scaleExact(
    Binary64Exact source,
    ulong numerator,
    ulong denominator)
{
    assert(denominator != 0);

    if (source.significand == 0 || numerator == 0)
        return RoundedRational(0, 0, false);

    ulong s = source.significand;
    ulong n = numerator;
    ulong d = denominator;
    int exponent2 = source.exponent2;

    auto g = gcd(s, d);
    s /= g;
    d /= g;

    g = gcd(n, d);
    n /= g;
    d /= g;

    while ((n & 1UL) == 0)
    {
        n >>= 1;
        ++exponent2;
    }

    while ((d & 1UL) == 0)
    {
        d >>= 1;
        --exponent2;
    }

    const exactNumerator =
        mul(fromUlong128(s), fromUlong128(n));

    // Determine floor(log2(exactNumerator / d)) exactly.
    // Start from the bit-length difference, then correct by one comparison.
    int ratioExponent = centBitLength(exactNumerator) - bitLength(d);

    if (ratioExponent >= 0)
    {
        bool shiftOverflow;
        const scaledDen =
            shlCent(fromUlong128(d), ratioExponent, shiftOverflow);

        if (shiftOverflow || centGreater(scaledDen, exactNumerator))
            --ratioExponent;
    }
    else
    {
        bool shiftOverflow;
        const scaledNum =
            shlCent(exactNumerator, -ratioExponent, shiftOverflow);

        if (!shiftOverflow
            && centGreater(fromUlong128(d), scaledNum))
            --ratioExponent;
    }

    // Let r = exactNumerator / d. The represented value is r * 2^exponent2.
    // Normal values use a 53-bit significand. Subnormal values must instead be
    // rounded directly onto the fixed 2^-1074 lattice. Rounding first to 53
    // bits and then again to the subnormal lattice can introduce a 1-ULP
    // double-rounding error.
    const int exactTopExponent = exponent2 + ratioExponent;

    if (exactTopExponent < -1022)
    {
        // Direct subnormal quantization:
        //
        //   quanta = round((exactNumerator / d) * 2^(exponent2 + 1074))
        //
        // The returned exponent is already the final subnormal quantum.
        const int quantumShift = exponent2 + 1074;

        Cent scaledNumerator = exactNumerator;
        ulong scaledDenominator = d;

        if (quantumShift > 0)
        {
            bool shiftOverflow;
            scaledNumerator = shlCent(
                scaledNumerator, quantumShift, shiftOverflow);
            if (shiftOverflow)
                return RoundedRational(0, 0, true);
        }
        else if (quantumShift < 0)
        {
            const shift = -quantumShift;
            if (shift >= 64 || scaledDenominator > (ulong.max >> shift))
            {
                // The exact magnitude is less than half a minimum subnormal,
                // so round-to-nearest-even is zero.
                return RoundedRational(0, -1074, false);
            }

            scaledDenominator <<= shift;
        }

        const quanta = roundCentQuotientNearestEven(
            scaledNumerator, scaledDenominator);

        return RoundedRational(quanta, -1074, false);
    }

    // Normal quantization:
    //
    //   M = round(r * 2^(52 - ratioExponent))
    //   E = exponent2 + ratioExponent - 52
    //
    // Note that exponent2 belongs only in E. It must not also influence the
    // scaling used to compute M.
    const int targetExponent = exponent2 + ratioExponent - 52;
    const int significandShift = 52 - ratioExponent;

    Cent scaledNumerator = exactNumerator;
    ulong scaledDenominator = d;

    if (significandShift > 0)
    {
        bool shiftOverflow;
        scaledNumerator = shlCent(
            scaledNumerator, significandShift, shiftOverflow);
        if (shiftOverflow)
            return RoundedRational(0, 0, true);
    }
    else if (significandShift < 0)
    {
        const shift = -significandShift;
        if (shift >= 64 || scaledDenominator > (ulong.max >> shift))
            return RoundedRational(0, 0, true);

        scaledDenominator <<= shift;
    }

    ulong rounded = roundCentQuotientNearestEven(
        scaledNumerator, scaledDenominator);

    int roundedExponent = targetExponent;

    if (bitLength(rounded) > 53)
    {
        rounded >>= 1;
        ++roundedExponent;
    }

    // The largest finite binary64 is
    //
    //   (2^53 - 1) * 2^971.
    //
    // For exact values whose unbiased top exponent is 1024, the ordinary
    // 53-bit normalization above targets exponent 972 and therefore loses the
    // finite interval that must still round back to double.max. Re-evaluate
    // that narrow boundary directly against the overflow midpoint:
    //
    //   (2^54 - 1) * 2^970.
    //
    // Values below the midpoint round to double.max; midpoint and above round
    // to infinity under round-to-nearest, ties-to-even.
    if (exactTopExponent == 1024)
    {
        // Compare exactNumerator / d * 2^exponent2 with
        // (2^54 - 1) * 2^970 without using floating arithmetic.
        const int midpointShift = 970 - exponent2;
        Cent lhs = exactNumerator;
        Cent rhs = mul(
            fromUlong128(d),
            fromUlong128((1UL << 54) - 1UL));

        if (midpointShift > 0)
        {
            bool shiftOverflow;
            rhs = shlCent(rhs, midpointShift, shiftOverflow);
            if (shiftOverflow)
                return RoundedRational(
                    (1UL << 53) - 1UL, 971, false);
        }
        else if (midpointShift < 0)
        {
            bool shiftOverflow;
            lhs = shlCent(lhs, -midpointShift, shiftOverflow);
            if (shiftOverflow)
                return RoundedRational(0, 0, true);
        }

        if (centGreater(rhs, lhs))
            return RoundedRational((1UL << 53) - 1UL, 971, false);

        return RoundedRational(0, 0, true);
    }

    if (roundedExponent > 971)
        return RoundedRational(0, 0, true);

    return RoundedRational(rounded, roundedExponent, false);
}

@safe pure nothrow @nogc
RoundedRational quantizeBinary64(RoundedRational value)
{
    if (value.overflow || value.significand == 0)
        return value;

    int bits = bitLength(value.significand);
    int topExponent = value.exponent2 + bits - 1;

    if (topExponent > 1023)
        return RoundedRational(0, 0, true);

    if (topExponent >= -1022)
        return value;

    const shiftToQuantum = -1074 - value.exponent2;

    if (shiftToQuantum <= 0)
        return value;

    if (shiftToQuantum >= 64)
    {
        value.significand = 0;
        value.exponent2 = -1074;
        return value;
    }

    const mask = (1UL << shiftToQuantum) - 1UL;
    const remainder = value.significand & mask;
    ulong quanta = value.significand >> shiftToQuantum;
    const halfway = 1UL << (shiftToQuantum - 1);

    if (remainder > halfway
        || (remainder == halfway && (quanta & 1UL) != 0))
    {
        ++quanta;
    }

    value.significand = quanta;
    value.exponent2 = -1074;
    return value;
}

@safe pure nothrow @nogc
double rebuild(bool negative, RoundedRational value)
{
    value = quantizeBinary64(value);

    if (value.overflow)
        return negative ? -double.infinity : double.infinity;

    if (value.significand == 0)
        return negative ? -0.0 : 0.0;

    // value.significand is already rounded to at most 53 bits. Converting that
    // integer to double is therefore exact, and ldexp only applies a power of
    // two. No additional decimal/rational rounding decision is permitted here.
    const double exactSignificand = cast(double) value.significand;
    const double result = ldexp(exactSignificand, value.exponent2);

    return negative ? -result : result;
}


struct ExactRational128
{
    Cent numerator;
    Cent denominator;
    int exponent2;
    bool negative;
}

struct UInt192
{
    ulong lo;
    ulong mid;
    ulong hi;
}

struct ExactRational192
{
    UInt192 numerator;
    ulong denominator;
    int exponent2;
    bool negative;
}

@safe pure nothrow @nogc
UInt192 fromUlong192(ulong value)
{
    return UInt192(value, 0, 0);
}

@safe pure nothrow @nogc
UInt192 fromCent192(Cent value)
{
    return UInt192(value.lo, value.hi, 0);
}

@safe pure nothrow @nogc
int compare192(UInt192 a, UInt192 b)
{
    if (a.hi < b.hi) return -1;
    if (a.hi > b.hi) return 1;
    if (a.mid < b.mid) return -1;
    if (a.mid > b.mid) return 1;
    if (a.lo < b.lo) return -1;
    if (a.lo > b.lo) return 1;
    return 0;
}

@safe pure nothrow @nogc
UInt192 subtract192(UInt192 a, UInt192 b)
{
    assert(compare192(a, b) >= 0);

    const borrow0 = a.lo < b.lo ? 1UL : 0UL;
    const lo = a.lo - b.lo;

    const midSub = b.mid + borrow0;
    const midCarry = midSub < b.mid ? 1UL : 0UL;
    const borrow1 = (a.mid < midSub || midCarry != 0) ? 1UL : 0UL;
    const mid = a.mid - midSub;

    return UInt192(
        lo,
        mid,
        a.hi - b.hi - borrow1);
}

@safe pure nothrow @nogc
UInt192 shiftLeft192(UInt192 value, int shift)
{
    assert(shift >= 0);

    foreach (_; 0 .. shift)
    {
        assert((value.hi & (1UL << 63)) == 0);
        value.hi = (value.hi << 1) | (value.mid >> 63);
        value.mid = (value.mid << 1) | (value.lo >> 63);
        value.lo <<= 1;
    }

    return value;
}

@safe pure nothrow @nogc
int bitLength192(UInt192 value)
{
    if (value.hi != 0)
        return 128 + bitLength(value.hi);
    if (value.mid != 0)
        return 64 + bitLength(value.mid);
    return bitLength(value.lo);
}

@safe pure nothrow @nogc
UInt192 multiplyCentUlong192(Cent a, ulong b)
{
    const p0 = mul(
        fromUlong128(a.lo),
        fromUlong128(b));
    const p1 = mul(
        fromUlong128(a.hi),
        fromUlong128(b));

    const mid = p0.hi + p1.lo;
    const carry = mid < p0.hi ? 1UL : 0UL;
    const hi = p1.hi + carry;

    assert(hi >= p1.hi);

    return UInt192(
        p0.lo,
        mid,
        hi);
}

struct Normalized192Ratio
{
    UInt192 numerator;
    UInt192 denominator;
    int exponent2;
}

@safe pure nothrow @nogc
Normalized192Ratio normalize192Ratio(
    UInt192 numerator,
    ulong denominator)
{
    assert(bitLength192(numerator) != 0);
    assert(denominator != 0);

    int exponent2 =
        bitLength192(numerator) -
        bitLength(denominator);

    UInt192 a;
    UInt192 b;

    if (exponent2 >= 0)
    {
        a = numerator;
        b = shiftLeft192(
            fromUlong192(denominator),
            exponent2);
    }
    else
    {
        a = shiftLeft192(
            numerator,
            -exponent2);
        b = fromUlong192(denominator);
    }

    if (compare192(a, b) < 0)
    {
        --exponent2;

        if (exponent2 >= 0)
        {
            a = numerator;
            b = shiftLeft192(
                fromUlong192(denominator),
                exponent2);
        }
        else
        {
            a = shiftLeft192(
                numerator,
                -exponent2);
            b = fromUlong192(denominator);
        }
    }

    assert(compare192(a, b) >= 0);

    return Normalized192Ratio(a, b, exponent2);
}

@safe pure nothrow @nogc
ulong roundedNormalizedSignificand192(
    UInt192 numerator,
    UInt192 denominator,
    int fractionBits)
{
    assert(fractionBits >= 0 && fractionBits <= 52);
    assert(compare192(numerator, denominator) >= 0);

    ulong result = 1UL << fractionBits;
    UInt192 remainder = subtract192(
        numerator,
        denominator);

    foreach (i; 0 .. fractionBits)
    {
        remainder = shiftLeft192(remainder, 1);

        if (compare192(remainder, denominator) >= 0)
        {
            result |= 1UL << (fractionBits - 1 - i);
            remainder = subtract192(
                remainder,
                denominator);
        }
    }

    const doubledRemainder =
        shiftLeft192(remainder, 1);
    const cmp = compare192(
        doubledRemainder,
        denominator);

    if (cmp > 0 || (cmp == 0 && (result & 1UL) != 0))
        ++result;

    return result;
}

@safe pure nothrow @nogc
double quantizeExactBinary64(ExactRational192 exact)
{
    assert(bitLength192(exact.numerator) != 0);
    assert(exact.denominator != 0);

    const normalized = normalize192Ratio(
        exact.numerator,
        exact.denominator);

    int topExponent =
        exact.exponent2 +
        normalized.exponent2;

    const signBits =
        exact.negative ? (1UL << 63) : 0UL;

    if (topExponent > 1023)
        return binary64FromBits(
            signBits | (0x7ffUL << 52));

    if (topExponent >= -1022)
    {
        ulong significand =
            roundedNormalizedSignificand192(
                normalized.numerator,
                normalized.denominator,
                52);

        if (significand == (1UL << 53))
        {
            significand >>= 1;
            ++topExponent;

            if (topExponent > 1023)
                return binary64FromBits(
                    signBits | (0x7ffUL << 52));
        }

        const exponentField =
            cast(ulong)(topExponent + 1023);
        const fraction =
            significand - (1UL << 52);

        return binary64FromBits(
            signBits |
            (exponentField << 52) |
            fraction);
    }

    const quantumPower = topExponent + 1074;
    ulong quanta;

    if (quantumPower < -1)
    {
        quanta = 0;
    }
    else if (quantumPower == -1)
    {
        quanta =
            compare192(
                normalized.numerator,
                normalized.denominator) == 0
                ? 0UL
                : 1UL;
    }
    else
    {
        assert(quantumPower <= 51);
        quanta =
            roundedNormalizedSignificand192(
                normalized.numerator,
                normalized.denominator,
                quantumPower);
    }

    if (quanta == 0)
        return binary64FromBits(signBits);

    if (quanta == (1UL << 52))
        return binary64FromBits(
            signBits | (1UL << 52));

    assert(quanta < (1UL << 52));
    return binary64FromBits(signBits | quanta);
}


struct NormalizedCentRatio
{
    Cent numerator;
    Cent denominator;
    int exponent2;
}

@safe pure nothrow @nogc
int compareCent(Cent a, Cent b)
{
    if (a.hi < b.hi) return -1;
    if (a.hi > b.hi) return 1;
    if (a.lo < b.lo) return -1;
    if (a.lo > b.lo) return 1;
    return 0;
}

@safe pure nothrow @nogc
Cent subtractCent(Cent a, Cent b)
{
    assert(compareCent(a, b) >= 0);

    const borrow = a.lo < b.lo ? 1UL : 0UL;
    return Cent(
        a.lo - b.lo,
        a.hi - b.hi - borrow);
}

@safe pure nothrow @nogc
Cent shiftCentExact(Cent value, int shift)
{
    bool overflow;
    const result = shlCent(value, shift, overflow);
    assert(!overflow);
    return result;
}

@safe pure nothrow @nogc
void cancel(ref ulong a, ref ulong b)
{
    const g = gcd(a, b);
    if (g > 1)
    {
        a /= g;
        b /= g;
    }
}

@safe pure nothrow @nogc
NormalizedCentRatio normalizeCentRatio(
    Cent numerator,
    Cent denominator)
{
    assert(!centIsZero(numerator));
    assert(!centIsZero(denominator));

    int exponent2 =
        centBitLength(numerator) -
        centBitLength(denominator);

    Cent a;
    Cent b;

    if (exponent2 >= 0)
    {
        a = numerator;
        b = shiftCentExact(denominator, exponent2);
    }
    else
    {
        a = shiftCentExact(numerator, -exponent2);
        b = denominator;
    }

    if (compareCent(a, b) < 0)
    {
        --exponent2;

        if (exponent2 >= 0)
        {
            a = numerator;
            b = shiftCentExact(denominator, exponent2);
        }
        else
        {
            a = shiftCentExact(numerator, -exponent2);
            b = denominator;
        }
    }

    assert(compareCent(a, b) >= 0);

    return NormalizedCentRatio(
        a,
        b,
        exponent2);
}

@safe pure nothrow @nogc
ulong roundedNormalizedSignificand(
    Cent numerator,
    Cent denominator,
    int fractionBits)
{
    assert(fractionBits >= 0 && fractionBits <= 52);
    assert(compareCent(numerator, denominator) >= 0);

    ulong result = 1UL << fractionBits;
    Cent remainder = subtractCent(numerator, denominator);

    foreach (i; 0 .. fractionBits)
    {
        remainder = shiftCentExact(remainder, 1);

        if (compareCent(remainder, denominator) >= 0)
        {
            result |= 1UL << (fractionBits - 1 - i);
            remainder = subtractCent(remainder, denominator);
        }
    }

    const doubledRemainder = shiftCentExact(remainder, 1);
    const cmp = compareCent(doubledRemainder, denominator);

    if (cmp > 0 || (cmp == 0 && (result & 1UL) != 0))
        ++result;

    return result;
}

@safe pure nothrow @nogc
double binary64FromBits(ulong bits)
{
    double value;

    () @trusted {
        memcpy(&value, &bits, double.sizeof);
    }();

    return value;
}

@safe pure nothrow @nogc
bool binary64Finite(double value)
{
    return ((binary64Bits(value) >> 52) & 0x7ffUL) != 0x7ffUL;
}

@safe pure nothrow @nogc
bool binary64Zero(double value)
{
    return (binary64Bits(value) & 0x7fff_ffff_ffff_ffffUL) == 0;
}

@safe pure nothrow @nogc
double quantizeExactBinary64(ExactRational128 exact)
{
    assert(!centIsZero(exact.numerator));
    assert(!centIsZero(exact.denominator));

    const normalized = normalizeCentRatio(
        exact.numerator,
        exact.denominator);

    int topExponent =
        exact.exponent2 +
        normalized.exponent2;

    const signBits =
        exact.negative ? (1UL << 63) : 0UL;

    if (topExponent > 1023)
        return binary64FromBits(
            signBits | (0x7ffUL << 52));

    if (topExponent >= -1022)
    {
        ulong significand =
            roundedNormalizedSignificand(
                normalized.numerator,
                normalized.denominator,
                52);

        if (significand == (1UL << 53))
        {
            significand >>= 1;
            ++topExponent;

            if (topExponent > 1023)
                return binary64FromBits(
                    signBits | (0x7ffUL << 52));
        }

        const exponentField =
            cast(ulong)(topExponent + 1023);
        const fraction =
            significand - (1UL << 52);

        return binary64FromBits(
            signBits |
            (exponentField << 52) |
            fraction);
    }

    const quantumPower = topExponent + 1074;
    ulong quanta;

    if (quantumPower < -1)
    {
        quanta = 0;
    }
    else if (quantumPower == -1)
    {
        // The value is normalizedRatio * 0.5 minimum-subnormal quanta.
        // Exactly normalizedRatio == 1 is the tie and rounds to even zero.
        quanta =
            centEqual(
                normalized.numerator,
                normalized.denominator)
                ? 0UL
                : 1UL;
    }
    else
    {
        assert(quantumPower <= 51);
        quanta =
            roundedNormalizedSignificand(
                normalized.numerator,
                normalized.denominator,
                quantumPower);
    }

    if (quanta == 0)
        return binary64FromBits(signBits);

    if (quanta == (1UL << 52))
    {
        // Rounding at the top of the subnormal lattice reaches min_normal.
        return binary64FromBits(
            signBits | (1UL << 52));
    }

    assert(quanta < (1UL << 52));
    return binary64FromBits(signBits | quanta);
}

@safe pure nothrow @nogc
ExactRational192 productExactBinary64(
    Binary64Exact lhs,
    Binary64Exact rhs,
    ulong scaleNumerator,
    ulong scaleDenominator)
{
    assert(lhs.significand != 0);
    assert(rhs.significand != 0);
    assert(scaleNumerator != 0);
    assert(scaleDenominator != 0);

    ulong x = lhs.significand;
    ulong y = rhs.significand;
    ulong n = scaleNumerator;
    ulong d = scaleDenominator;

    cancel(x, d);
    cancel(y, d);
    cancel(n, d);

    const xy = mul(
        fromUlong128(x),
        fromUlong128(y));
    const numerator =
        multiplyCentUlong192(xy, n);

    // R04.15 structural bounds for represented binary64 operands and the
    // current ExactRatio range are <=169 numerator bits and <=63 denominator
    // bits after exact cancellation.
    assert(bitLength192(numerator) <= 169);
    assert(bitLength(d) <= 63);

    return ExactRational192(
        numerator,
        d,
        lhs.exponent2 + rhs.exponent2,
        lhs.negative != rhs.negative);
}

@safe pure nothrow @nogc
double quantizeProductBinary64(ExactRational192 exact)
{
    // Conservative fast-path threshold established by R04.15 Probe 8D-P.
    // The value is already exact; narrowing here changes representation only.
    if (bitLength192(exact.numerator) <= 127)
    {
        assert(exact.numerator.hi == 0);

        return quantizeExactBinary64(
            ExactRational128(
                Cent(
                    exact.numerator.lo,
                    exact.numerator.mid),
                fromUlong128(exact.denominator),
                exact.exponent2,
                exact.negative));
    }

    return quantizeExactBinary64(exact);
}

@safe pure nothrow @nogc
ExactRational128 quotientExactBinary64(
    Binary64Exact lhs,
    Binary64Exact rhs,
    ulong scaleNumerator,
    ulong scaleDenominator)
{
    assert(lhs.significand != 0);
    assert(rhs.significand != 0);
    assert(scaleNumerator != 0);
    assert(scaleDenominator != 0);

    ulong x = lhs.significand;
    ulong y = rhs.significand;
    ulong n = scaleNumerator;
    ulong d = scaleDenominator;

    cancel(x, y);
    cancel(x, d);
    cancel(n, y);
    cancel(n, d);

    const numerator =
        mul(fromUlong128(x), fromUlong128(n));
    const denominator =
        mul(fromUlong128(y), fromUlong128(d));

    // R04.15 structural bounds for represented binary64 operands and the
    // current ExactRatio public range are <=116 bits on both sides.
    assert(centBitLength(numerator) <= 116);
    assert(centBitLength(denominator) <= 116);

    return ExactRational128(
        numerator,
        denominator,
        lhs.exponent2 - rhs.exponent2,
        lhs.negative != rhs.negative);
}



// Conversion range is a mathematical property before target rounding.
// The IEEE quantizer below deliberately uses the infinity midpoint instead.
package @safe pure nothrow @nogc
bool rationalResultWithinBinary64Range(
    double value,
    long numerator,
    long denominator)
{
    assert(denominator > 0);
    assert(value == value && value <= double.max && value >= -double.max);

    const n = numerator < 0
        ? cast(ulong)(-(numerator + 1)) + 1UL
        : cast(ulong) numerator;
    const d = cast(ulong) denominator;

    // A finite source scaled by a magnitude <= 1 cannot leave the range.
    if (value == 0.0 || n <= d)
        return true;

    const source = decompose(value);

    // Compare |source| * n / d with (2^53 - 1) * 2^971.
    // Both products fit in Cent: a binary64 significand uses <= 53 bits
    // and each integral factor uses <= 64 bits. Finite source exponent2
    // is <= 971, so only the bound ever needs a nonnegative left shift.
    const lhs = mul(fromUlong128(source.significand), fromUlong128(n));
    const rhs = mul(fromUlong128((1UL << 53) - 1UL), fromUlong128(d));
    const shift = 971 - source.exponent2;
    const lhsBits = centBitLength(lhs);
    const rhsBits = centBitLength(rhs) + shift;

    if (lhsBits != rhsBits)
        return lhsBits < rhsBits;

    // Equal bit lengths prove the shifted bound fits in Cent.
    bool shiftOverflow;
    const bound = shlCent(rhs, shift, shiftOverflow);
    assert(!shiftOverflow);
    return !centGreater(lhs, bound);
}


public:
@safe pure nothrow @nogc
Binary64ScaleResult scaleBinary64(
    double value,
    long numerator,
    long denominator)
{
    assert(denominator > 0);

    if (value == 0.0 || numerator == 0)
    {
        // Numeric comparison cannot distinguish +0.0 from -0.0. Preserve the
        // stored source sign and combine it with the scale sign exactly.
        const sourceNegative = (binary64Bits(value) >> 63) != 0;
        return Binary64ScaleResult(
            sourceNegative != (numerator < 0) ? -0.0 : 0.0,
            false);
    }

    const source = decompose(value);

    const numeratorMagnitude = numerator < 0
        ? cast(ulong)(-(numerator + 1)) + 1UL
        : cast(ulong) numerator;

    auto scaled = scaleExact(
        source, numeratorMagnitude, cast(ulong) denominator);

    scaled = quantizeBinary64(scaled);
    if (scaled.overflow)
        return Binary64ScaleResult(0.0, true);

    const negative = source.negative != (numerator < 0);
    return Binary64ScaleResult(rebuild(negative, scaled), false);
}

/// Evaluate (lhs * rhs) * numerator / denominator from the represented
/// binary64 operands as one exact rational expression and round exactly once.
///
/// Finite nonzero inputs use the R04.15 Cent fast path / UInt192 fallback.
/// IEEE special values retain native product behavior. Nontrivial represented-
/// source rescale is intentionally runtime-only.
@safe pure nothrow @nogc
double rescaleProductBinary64(
    double lhs,
    double rhs,
    long numerator,
    long denominator)
{
    assert(numerator > 0);
    assert(denominator > 0);

    if (__ctfe)
    {
        assert(false,
            "quantities-d: nontrivial binary64 product rescale "
            ~ "requires runtime represented-source semantics");
    }

    if (!binary64Finite(lhs)
        || !binary64Finite(rhs)
        || binary64Zero(lhs)
        || binary64Zero(rhs))
    {
        return lhs * rhs;
    }

    const exact = productExactBinary64(
        decompose(lhs),
        decompose(rhs),
        cast(ulong)numerator,
        cast(ulong)denominator);

    return quantizeProductBinary64(exact);
}

/// Evaluate (lhs / rhs) * numerator / denominator from the represented
/// binary64 operands as one exact rational expression and round exactly once.
///
/// This is intentionally runtime-only for nontrivial rescale semantics:
/// ordinary D CTFE may retain excess precision beyond binary64 storage.
@safe pure nothrow @nogc
double rescaleQuotientBinary64(
    double lhs,
    double rhs,
    long numerator,
    long denominator)
{
    assert(numerator > 0);
    assert(denominator > 0);

    if (__ctfe)
    {
        assert(false,
            "quantities-d: nontrivial binary64 quotient rescale "
            ~ "requires runtime represented-source semantics");
    }

    // Positive finite rescaling cannot alter the IEEE class/sign of a native
    // quotient that is already zero, infinity, or NaN.
    if (!binary64Finite(lhs)
        || !binary64Finite(rhs)
        || binary64Zero(lhs)
        || binary64Zero(rhs))
    {
        return lhs / rhs;
    }

    const exact = quotientExactBinary64(
        decompose(lhs),
        decompose(rhs),
        cast(ulong)numerator,
        cast(ulong)denominator);

    return quantizeExactBinary64(exact);
}

@safe unittest
{
    // ADR 0007: represented-source binary64 semantics are a runtime contract.
    // The exact bit decomposition uses memcpy and is intentionally not CTFE.
    const minSubnormal = double.min_normal * double.epsilon;

    const maxTwoThirds = scaleBinary64(double.max, 2, 3);
    assert(!maxTwoThirds.overflow);
    assert(maxTwoThirds.value > 0.0);
    assert(maxTwoThirds.value <= double.max);

    const subnormalTie = scaleBinary64(minSubnormal, 3, 2);
    assert(!subnormalTie.overflow);
    assert(subnormalTie.value == minSubnormal * 2.0);

    // Regression: round the exact rational value directly to the subnormal
    // lattice. A prior 53-bit rounding step produces the adjacent lower ULP.
    const doubleRoundSource = ldexp(2950364274258428.0, -1074);
    const doubleRoundExpected = ldexp(2598665221697821.0, -1074);
    const doubleRound = scaleBinary64(doubleRoundSource, 133, 151);
    assert(!doubleRound.overflow);
    assert(doubleRound.value == doubleRoundExpected);

    const halfMin = scaleBinary64(minSubnormal, 1, 2);
    assert(!halfMin.overflow);
    assert(halfMin.value == 0.0);
    assert((binary64Bits(halfMin.value) >> 63) == 0);

    const negativeHalfMin = scaleBinary64(-minSubnormal, 1, 2);
    assert(!negativeHalfMin.overflow);
    assert(negativeHalfMin.value == 0.0);
    assert((binary64Bits(negativeHalfMin.value) >> 63) == 1);

    const negativeZeroPositiveScale = scaleBinary64(-0.0, 1, 1);
    assert(!negativeZeroPositiveScale.overflow);
    assert((binary64Bits(negativeZeroPositiveScale.value) >> 63) == 1);

    const positiveZeroNegativeScale = scaleBinary64(0.0, -1, 1);
    assert(!positiveZeroNegativeScale.overflow);
    assert((binary64Bits(positiveZeroNegativeScale.value) >> 63) == 1);

    const negativeZeroNegativeScale = scaleBinary64(-0.0, -1, 1);
    assert(!negativeZeroNegativeScale.overflow);
    assert((binary64Bits(negativeZeroNegativeScale.value) >> 63) == 0);

    // Normal/subnormal transition. The exact midpoint between the largest
    // subnormal and the smallest normal binary64 value is
    //
    //   min_normal - 0.5 * min_subnormal.
    //
    // Ties-to-even selects min_normal because its least-significant stored
    // significand bit is even, while the largest subnormal is odd.
    const belowNormalMidpoint = scaleBinary64(
        double.min_normal,
        18014398509481981L,
        18014398509481984L);
    assert(!belowNormalMidpoint.overflow);
    assert(belowNormalMidpoint.value
        == double.min_normal - minSubnormal);

    const atNormalMidpoint = scaleBinary64(
        double.min_normal,
        9007199254740991L,
        9007199254740992L);
    assert(!atNormalMidpoint.overflow);
    assert(atNormalMidpoint.value == double.min_normal);

    const aboveNormalMidpoint = scaleBinary64(
        double.min_normal,
        18014398509481983L,
        18014398509481984L);
    assert(!aboveNormalMidpoint.overflow);
    assert(aboveNormalMidpoint.value == double.min_normal);

    const negativeBelowNormalMidpoint = scaleBinary64(
        -double.min_normal,
        18014398509481981L,
        18014398509481984L);
    assert(!negativeBelowNormalMidpoint.overflow);
    assert(negativeBelowNormalMidpoint.value
        == -(double.min_normal - minSubnormal));

    const negativeAtNormalMidpoint = scaleBinary64(
        -double.min_normal,
        9007199254740991L,
        9007199254740992L);
    assert(!negativeAtNormalMidpoint.overflow);
    assert(negativeAtNormalMidpoint.value == -double.min_normal);

    const negativeAboveNormalMidpoint = scaleBinary64(
        -double.min_normal,
        18014398509481983L,
        18014398509481984L);
    assert(!negativeAboveNormalMidpoint.overflow);
    assert(negativeAboveNormalMidpoint.value == -double.min_normal);

    const trueOverflow = scaleBinary64(double.max, 2, 1);
    assert(trueOverflow.overflow);

    const belowOverflowMidpoint = scaleBinary64(
        double.max,
        18014398509481984L,
        18014398509481983L);
    assert(!belowOverflowMidpoint.overflow);
    assert(belowOverflowMidpoint.value == double.max);

    const atOverflowMidpoint = scaleBinary64(
        double.max,
        18014398509481983L,
        18014398509481982L);
    assert(atOverflowMidpoint.overflow);

    const aboveOverflowMidpoint = scaleBinary64(
        double.max,
        18014398509481982L,
        18014398509481981L);
    assert(aboveOverflowMidpoint.overflow);

    const negative = scaleBinary64(-1.5, 2, 3);
    assert(!negative.overflow);
    assert(negative.value == -1.0);

    const tenth = scaleBinary64(1.0, 1, 10);
    assert(!tenth.overflow);
    assert(tenth.value == 0.1);

    // R04.15 product: evaluating the native product first overflows, while
    // the exact joint expression (double.max * 2) * 1/2 is double.max.
    const productOverflowAvoided =
        rescaleProductBinary64(
            double.max,
            2.0,
            1,
            2);
    assert(productOverflowAvoided == double.max);

    // Scaling one operand first can underflow even though the joint exact
    // result is one minimum subnormal.
    const productUnderflowAvoided =
        rescaleProductBinary64(
            minSubnormal,
            2.0,
            1,
            2);
    assert(productUnderflowAvoided == minSubnormal);

    const productSimple =
        rescaleProductBinary64(
            1.5,
            2.0,
            2,
            3);
    assert(productSimple == 2.0);

    const productOverflow =
        rescaleProductBinary64(
            double.max,
            2.0,
            1,
            1);
    assert(productOverflow == double.infinity);

    const productNaN =
        rescaleProductBinary64(
            double.infinity,
            0.0,
            2,
            3);
    assert(productNaN != productNaN);

    const productNegativeZero =
        rescaleProductBinary64(
            -0.0,
            2.0,
            2,
            3);
    assert(productNegativeZero == 0.0);
    assert((binary64Bits(productNegativeZero) >> 63) == 1);

    // R04.15: nontrivial quotient rescale is evaluated jointly and rounded
    // once. Sequential quotient-first evaluation overflows here.
    const quotientOverflowAvoided =
        rescaleQuotientBinary64(
            double.max,
            0.5,
            1,
            2);
    assert(quotientOverflowAvoided == double.max);

    // Scaling the numerator first would underflow to zero. The joint exact
    // expression remains exactly one minimum subnormal.
    const quotientUnderflowAvoided =
        rescaleQuotientBinary64(
            minSubnormal,
            0.5,
            1,
            2);
    assert(quotientUnderflowAvoided == minSubnormal);

    const quotientSimple =
        rescaleQuotientBinary64(
            3.0,
            2.0,
            2,
            3);
    assert(quotientSimple == 1.0);

    const quotientOverflow =
        rescaleQuotientBinary64(
            double.max,
            0.5,
            1,
            1);
    assert(quotientOverflow == double.infinity);

    const quotientPositiveInfinity =
        rescaleQuotientBinary64(
            1.0,
            0.0,
            2,
            3);
    assert(quotientPositiveInfinity == double.infinity);

    const quotientNegativeInfinity =
        rescaleQuotientBinary64(
            1.0,
            -0.0,
            2,
            3);
    assert(quotientNegativeInfinity == -double.infinity);

    const quotientNegativeZero =
        rescaleQuotientBinary64(
            -1.0,
            double.infinity,
            2,
            3);
    assert(quotientNegativeZero == 0.0);
    assert((binary64Bits(quotientNegativeZero) >> 63) == 1);

    const quotientNaN =
        rescaleQuotientBinary64(
            0.0,
            0.0,
            2,
            3);
    assert(quotientNaN != quotientNaN);
}

@safe unittest
{
    // Frozen independent Fraction oracle, Python Random seed 46.
    // Each significand is <= 53 bits; ldexp reconstructs the source exactly.
    struct RangeCase
    {
        ulong significand;
        int exponent2;
        long numerator;
        long denominator;
        bool inRange;
    }

    immutable RangeCase[] cases = [
        RangeCase(5191601368697190UL, 971, long.min, 4611686018427387904L, false),
        RangeCase(4777330916264495UL, 908, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(5340563179506147UL, 906, 1439871105878836188L, 1L, true),
        RangeCase(5488824835409289UL, 940, 4672304329295478109L, 9223372036854775807L, true),
        RangeCase(5464384469983735UL, 908, 9223372036854775807L, 8041340976764821564L, true),
        RangeCase(7961113514336920UL, 908, long.min, 4611686018427387904L, true),
        RangeCase(5085367181785646UL, 910, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(6048893780277101UL, -1074, 607063374353756999L, 9223372036854775807L, true),
        RangeCase(8143998019700834UL, 971, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(5186001579702343UL, 906, long.min, 9223372036854775807L, true),
        RangeCase(7902024587955264UL, 969, 9223372036854775807L, 1217304719567535406L, false),
        RangeCase(5484789377214640UL, 940, 1116115387122968942L, 9223372036854775807L, true),
        RangeCase(7340575472050143UL, 907, 2511110234770054376L, 9223372036854775807L, true),
        RangeCase(4925007026515883UL, 971, 9223372036854775807L, 8244845793435337719L, true),
        RangeCase(7492444870302127UL, 907, 4611686018427387905L, 1L, true),
        RangeCase(4647756798740109UL, 910, 4611686018427387905L, 6061802359300275876L, true),
        RangeCase(5584507799070089UL, 908, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(5018721743886765UL, -375, 6533581809861907987L, 2353382507538416196L, true),
        RangeCase(5916766816668138UL, 970, long.min, 9223372036854775807L, true),
        RangeCase(8919672474470163UL, 906, long.min, 8378110883562347331L, true),
        RangeCase(8334880768869169UL, -1074, 4611686018427387905L, 2183058715807100793L, true),
        RangeCase(5635096543813681UL, 970, 4611686018427387905L, 1L, false),
        RangeCase(5461782464054009UL, -1074, long.min, 3392744768825224351L, true),
        RangeCase(8670791529178659UL, 969, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(6362166624159737UL, 908, long.min, 7127582094191410084L, true),
        RangeCase(4936629533422190UL, 908, 4611686018427387905L, 1L, true),
        RangeCase(8576077123515886UL, 971, long.min, 4611686018427387904L, false),
        RangeCase(7775414545762949UL, 971, 3037586093215500666L, 1730740369604110542L, false),
        RangeCase(8072826061156483UL, 908, 4611686018427387905L, 9223372036854775807L, true),
        RangeCase(6673176903128126UL, 907, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(4795765704788386UL, 910, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(5032430633420675UL, 969, 2512514805426155584L, 341341392062200829L, false),
        RangeCase(6777656767371548UL, 907, 6471869008691340200L, 8138794752874646127L, true),
        RangeCase(8847719811131589UL, 910, 4611686018427387905L, 1L, false),
        RangeCase(5851179796616221UL, 971, 9223372036854775807L, 1L, false),
        RangeCase(8406472353377722UL, -686, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(5767933123437765UL, 907, 3324156298791170193L, 9223372036854775807L, true),
        RangeCase(5984281009765383UL, 940, 4611686018427387905L, 9223372036854775807L, true),
        RangeCase(7413750010744338UL, 907, long.min, 4611686018427387904L, true),
        RangeCase(7669131667133776UL, -1074, 7710773725389246829L, 9071598371267024061L, true),
        RangeCase(5775935900895804UL, -568, 6630788820678942760L, 9223372036854775807L, true),
        RangeCase(8093667918207422UL, 910, 9223372036854775807L, 1L, false),
        RangeCase(8579268424454502UL, -346, 4611686018427387905L, 3837762948844704103L, true),
        RangeCase(5594868828908756UL, 969, 8992028555075398783L, 5248674673132021515L, true),
        RangeCase(6541527485128437UL, -1074, long.min, 4611686018427387904L, true),
        RangeCase(6460783412052160UL, 907, 9223372036854775807L, 1L, true),
        RangeCase(8953776327400552UL, 908, long.min, 9223372036854775807L, true),
        RangeCase(7514762135147754UL, 970, long.min, 4611686018427387904L, true),
        RangeCase(8887337450085068UL, 940, 4611686018427387905L, 9223372036854775807L, true),
        RangeCase(7622834295284310UL, 908, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(8740661174073117UL, -107, long.min, 7305518712145993386L, true),
        RangeCase(7214249774617420UL, 910, long.min, 244640726833767611L, true),
        RangeCase(8421447784045178UL, 970, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(7120977961036066UL, -1074, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(8686629313652949UL, 940, long.min, 3654235835926384563L, true),
        RangeCase(5539888143719421UL, -1074, long.min, 9223372036854775807L, true),
        RangeCase(5598168229354695UL, 279, 4611686018427387905L, 1L, true),
        RangeCase(8430194679943501UL, 970, 8263329030838342980L, 4649579860481850790L, true),
        RangeCase(6582055933207041UL, 940, 4611686018427387905L, 1L, false),
        RangeCase(4983054527649411UL, 970, 9110206501376015869L, 4611686018427387904L, true),
        RangeCase(6411713422719284UL, 969, long.min, 1L, false),
        RangeCase(7165470207246549UL, 907, long.min, 9223372036854775807L, true),
        RangeCase(7479415837118950UL, 907, long.min, 9223372036854775807L, true),
        RangeCase(8209977652345440UL, 908, long.min, 9223372036854775807L, true),
        RangeCase(5380575508761156UL, 907, long.min, 1019692692220868264L, true),
        RangeCase(5217133357342533UL, 907, long.min, 4611686018427387904L, true),
        RangeCase(4532219786362661UL, 970, 7186224666896307044L, 9223372036854775807L, true),
        RangeCase(6370926464497476UL, 910, 4611686018427387905L, 1L, false),
        RangeCase(7317376626294856UL, -428, long.min, 9223372036854775807L, true),
        RangeCase(8476701752308457UL, 908, 5334561166591586799L, 1L, true),
        RangeCase(8338844361026189UL, 908, 2280392289141433028L, 2375348923774607828L, true),
        RangeCase(5642971850709157UL, 885, 9223372036854775807L, 1L, true),
        RangeCase(8883665264103724UL, 910, 524929764696927501L, 4611686018427387904L, true),
        RangeCase(7634044033767386UL, -808, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(6919361343337580UL, 910, 5100478525077644069L, 4611686018427387904L, true),
        RangeCase(6140561770508081UL, 910, long.min, 1L, false),
        RangeCase(6545801567086166UL, 940, 8277230434050071408L, 1L, false),
        RangeCase(6615122895439860UL, 970, 4611686018427387905L, 1L, false),
        RangeCase(7288718840902254UL, 908, 8454880303111957095L, 4611686018427387904L, true),
        RangeCase(6304621927517112UL, 971, 9223372036854775807L, 4611686018427387904L, false),
        RangeCase(4894955372346421UL, 969, 4055145462329874077L, 4611686018427387904L, true),
        RangeCase(7983588087112442UL, 969, 4611686018427387905L, 1L, false),
        RangeCase(8629673245215431UL, 908, 2436772266785351684L, 4611686018427387904L, true),
        RangeCase(4792026892888390UL, 970, long.min, 9223372036854775807L, true),
        RangeCase(7353795839365086UL, -1074, 6363580765588976838L, 1L, true),
        RangeCase(6013517259877733UL, 970, 4611686018427387905L, 9223372036854775807L, true),
        RangeCase(5163932656056960UL, 971, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(4726867198579448UL, 940, 2836200906611305715L, 4358650233744964469L, true),
        RangeCase(8730736490864696UL, 969, 2446155346867481531L, 532523228373259384L, false),
        RangeCase(5199961857404397UL, 906, 3677831165270889097L, 7912207617958943337L, true),
        RangeCase(8259470350624496UL, 907, 5633431266229980880L, 9223372036854775807L, true),
        RangeCase(8028270293696314UL, 970, 9223372036854775807L, 4611686018427387904L, true),
        RangeCase(8353401751171266UL, 970, long.min, 4611686018427387904L, true),
        RangeCase(8018913243990226UL, 907, 9223372036854775807L, 4611686018427387904L, true),
        RangeCase(5569295888322442UL, 908, 9026859811975876858L, 1L, true),
        RangeCase(8812283334691573UL, 907, long.min, 4611686018427387904L, true),
        RangeCase(6881972931315289UL, 969, long.min, 1L, false),
        RangeCase(8183855502490384UL, 908, long.min, 5242743286499362122L, true),
        RangeCase(7451703569535122UL, -834, 9223372036854775807L, 1L, true),
        RangeCase(4553605451045134UL, 908, 6828579699254156034L, 1L, true),
        RangeCase(8842223662096417UL, 907, long.min, 9223372036854775807L, true),
        RangeCase(5454730305602842UL, 907, 5672920160691120624L, 9223372036854775807L, true),
        RangeCase(7912519127596313UL, -641, 45794311884630217L, 9223372036854775807L, true),
        RangeCase(5892505843157561UL, 971, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(5348094521706414UL, 908, long.min, 9223372036854775807L, true),
        RangeCase(6837911034693273UL, 918, 4611686018427387905L, 3702042097750363923L, true),
        RangeCase(8844476879487119UL, 971, 4611686018427387905L, 9223372036854775807L, true),
        RangeCase(8666888512779564UL, 907, 2384502166315764028L, 4620466849257324068L, true),
        RangeCase(5976387957645126UL, 910, 9223372036854775807L, 4611686018427387904L, true),
        RangeCase(5811745055656484UL, 970, 9223372036854775807L, 1L, false),
        RangeCase(8901880120288205UL, 940, 4611686018427387905L, 2080596652504274130L, true),
        RangeCase(4788447639128010UL, 910, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(6011190077553398UL, -1074, 4611686018427387905L, 4391125348697562574L, true),
        RangeCase(7953503847407689UL, 910, 5890012697527486802L, 1L, false),
        RangeCase(4632089954992849UL, 908, 9223372036854775807L, 9223372036854775807L, true),
        RangeCase(8639630937368382UL, 908, long.min, 4611686018427387904L, true),
        RangeCase(5057471654674926UL, 907, long.min, 8084419072849088864L, true),
        RangeCase(8659527323172838UL, 969, long.min, 1L, false),
        RangeCase(8791914059958585UL, -1074, 4611686018427387905L, 1L, true),
        RangeCase(6831671658509984UL, -611, long.min, 3262604167428291324L, true),
        RangeCase(6278972232922838UL, 969, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(5977021097615272UL, -1074, 5788405019604778642L, 4611686018427387904L, true),
        RangeCase(6754124765746780UL, 512, 4611686018427387905L, 1L, true),
        RangeCase(4989412333197171UL, 970, 4611686018427387905L, 4611686018427387904L, true),
        RangeCase(5039842094713122UL, 907, 9223372036854775807L, 9106355173395973888L, true),
        RangeCase(4552697821094492UL, 940, 9223372036854775807L, 1L, false),
        RangeCase(6444504964031050UL, 907, 9223372036854775807L, 4611686018427387904L, true),
        RangeCase(7116407232100346UL, 940, long.min, 9223372036854775807L, true),
    ];

    foreach (test; cases)
    {
        const source = ldexp(cast(double) test.significand, test.exponent2);
        assert(rationalResultWithinBinary64Range(
            source, test.numerator, test.denominator) == test.inRange);
        assert(rationalResultWithinBinary64Range(
            -source, test.numerator, test.denominator) == test.inRange);
    }
}
