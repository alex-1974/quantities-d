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
