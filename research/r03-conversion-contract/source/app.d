module app;

enum ConversionStatus
{
    exact,
    inexact,
    overflow
}

enum RoundingMode
{
    towardZero,
    floor,
    ceiling,
    nearestTiesAway
}

struct ConversionResult(T)
{
    ConversionStatus status;
    T value;
}

@safe pure nothrow @nogc
ulong magnitude(long value)
{
    if (value >= 0)
        return cast(ulong) value;
    return cast(ulong)(-(value + 1)) + 1UL;
}

@safe pure nothrow @nogc
ulong gcdUnsigned(ulong a, ulong b)
{
    while (b != 0)
    {
        const r = a % b;
        a = b;
        b = r;
    }
    return a;
}

// Research helper for signed long source/target and positive exact scale.
// It cross-cancels value magnitude against the denominator before checking
// multiplication, avoiding needless overflow.
@safe pure nothrow @nogc
ConversionResult!long checkedScale(long value, ulong num, ulong den)
{
    assert(den != 0);

    if (value == 0 || num == 0)
        return ConversionResult!long(ConversionStatus.exact, 0);

    auto mag = magnitude(value);
    const g = gcdUnsigned(mag, den);
    mag /= g;
    den /= g;

    if (num != 0 && mag > ulong.max / num)
        return ConversionResult!long(ConversionStatus.overflow, 0);

    const product = mag * num;
    if (product % den != 0)
        return ConversionResult!long(ConversionStatus.inexact, 0);

    const q = product / den;
    const negative = value < 0;

    if (negative)
    {
        const limit = cast(ulong) long.max + 1UL;
        if (q > limit)
            return ConversionResult!long(ConversionStatus.overflow, 0);
        if (q == limit)
            return ConversionResult!long(ConversionStatus.exact, long.min);
        return ConversionResult!long(ConversionStatus.exact, -cast(long) q);
    }

    if (q > cast(ulong) long.max)
        return ConversionResult!long(ConversionStatus.overflow, 0);

    return ConversionResult!long(ConversionStatus.exact, cast(long) q);
}

@safe pure nothrow @nogc
ConversionResult!long roundedScale(
    long value,
    ulong num,
    ulong den,
    RoundingMode mode)
{
    assert(den != 0);

    if (value == 0 || num == 0)
        return ConversionResult!long(ConversionStatus.exact, 0);

    auto mag = magnitude(value);
    const g = gcdUnsigned(mag, den);
    mag /= g;
    den /= g;

    if (num != 0 && mag > ulong.max / num)
        return ConversionResult!long(ConversionStatus.overflow, 0);

    const product = mag * num;
    auto q = product / den;
    const r = product % den;
    const negative = value < 0;

    if (r != 0)
    {
        bool increment;
        final switch (mode)
        {
            case RoundingMode.towardZero:
                increment = false;
                break;
            case RoundingMode.floor:
                increment = negative;
                break;
            case RoundingMode.ceiling:
                increment = !negative;
                break;
            case RoundingMode.nearestTiesAway:
                // r * 2 could overflow; compare without doubling r.
                increment = r > den / 2 || (den % 2 == 0 && r == den / 2);
                break;
        }

        if (increment)
        {
            if (q == ulong.max)
                return ConversionResult!long(ConversionStatus.overflow, 0);
            ++q;
        }
    }

    if (negative)
    {
        const limit = cast(ulong) long.max + 1UL;
        if (q > limit)
            return ConversionResult!long(ConversionStatus.overflow, 0);
        const result = q == limit ? long.min : -cast(long) q;
        return ConversionResult!long(
            r == 0 ? ConversionStatus.exact : ConversionStatus.inexact,
            result);
    }

    if (q > cast(ulong) long.max)
        return ConversionResult!long(ConversionStatus.overflow, 0);

    return ConversionResult!long(
        r == 0 ? ConversionStatus.exact : ConversionStatus.inexact,
        cast(long) q);
}

@safe pure nothrow @nogc
double floatingScale(long value, long num, long den)
{
    // Exact ratio is retained until this final floating operation.
    return cast(double) value * cast(double) num / cast(double) den;
}

void main()
{
    enum km = checkedScale(1, 1000, 1);
    static assert(km.status == ConversionStatus.exact && km.value == 1000);

    enum metre = checkedScale(1, 1, 1);
    static assert(metre.status == ConversionStatus.exact && metre.value == 1);

    enum mm = checkedScale(1, 1, 1000);
    static assert(mm.status == ConversionStatus.inexact);

    enum mm1500 = checkedScale(1500, 1, 1000);
    static assert(mm1500.status == ConversionStatus.inexact);

    enum mm2000 = checkedScale(2000, 1, 1000);
    static assert(mm2000.status == ConversionStatus.exact && mm2000.value == 2);

    enum negMin = checkedScale(long.min, 1, 1);
    static assert(negMin.status == ConversionStatus.exact && negMin.value == long.min);

    enum overflow = checkedScale(long.max, 2, 1);
    static assert(overflow.status == ConversionStatus.overflow);

    enum pToward = roundedScale(1500, 1, 1000, RoundingMode.towardZero);
    enum pFloor = roundedScale(1500, 1, 1000, RoundingMode.floor);
    enum pCeil = roundedScale(1500, 1, 1000, RoundingMode.ceiling);
    enum pNearest = roundedScale(1500, 1, 1000, RoundingMode.nearestTiesAway);
    static assert(pToward.value == 1);
    static assert(pFloor.value == 1);
    static assert(pCeil.value == 2);
    static assert(pNearest.value == 2);

    enum nToward = roundedScale(-1500, 1, 1000, RoundingMode.towardZero);
    enum nFloor = roundedScale(-1500, 1, 1000, RoundingMode.floor);
    enum nCeil = roundedScale(-1500, 1, 1000, RoundingMode.ceiling);
    enum nNearest = roundedScale(-1500, 1, 1000, RoundingMode.nearestTiesAway);
    static assert(nToward.value == -1);
    static assert(nFloor.value == -2);
    static assert(nCeil.value == -1);
    static assert(nNearest.value == -2);

    enum exactFoot = checkedScale(1250, 381, 1250);
    static assert(exactFoot.status == ConversionStatus.exact && exactFoot.value == 381);

    enum fp = floatingScale(1, 381, 1250);
    static assert(fp > 0.304799999999 && fp < 0.304800000001);
}


// ---------------------------------------------------------------------------
// Probe 2: representative Rep matrix.
// ---------------------------------------------------------------------------

template isIntegralRep(T)
{
    enum isIntegralRep = is(T == byte) || is(T == ubyte)
        || is(T == short) || is(T == ushort)
        || is(T == int) || is(T == uint)
        || is(T == long) || is(T == ulong);
}

template isFloatingRep(T)
{
    enum isFloatingRep = is(T == float) || is(T == double) || is(T == real);
}

@safe pure nothrow @nogc
ConversionResult!Target checkedIntegralScale(Target, Source)(
    Source value,
    ulong num,
    ulong den)
if (isIntegralRep!Target && isIntegralRep!Source)
{
    // M1 probe: reuse the proven signed-long kernel only where Source can be
    // represented losslessly as long. Generic unsigned-wide policy remains open.
    static assert(Source.min >= long.min && Source.max <= long.max,
        "probe currently requires Source range to fit in long");

    const scaled = checkedScale(cast(long) value, num, den);
    if (scaled.status != ConversionStatus.exact)
        return ConversionResult!Target(scaled.status, Target.init);

    static if (is(Target == ulong))
    {
        if (scaled.value < 0)
            return ConversionResult!Target(ConversionStatus.overflow, Target.init);
    }

    if (scaled.value < cast(long) Target.min || scaled.value > cast(long) Target.max)
        return ConversionResult!Target(ConversionStatus.overflow, Target.init);

    return ConversionResult!Target(
        ConversionStatus.exact,
        cast(Target) scaled.value);
}

@safe pure nothrow @nogc
Target integralToFloating(Target, Source)(
    Source value,
    long num,
    long den)
if (isFloatingRep!Target && isIntegralRep!Source)
{
    return cast(Target) value * cast(Target) num / cast(Target) den;
}

@safe pure nothrow @nogc
ConversionResult!Target checkedFloatingToIntegral(Target, Source)(
    Source value)
if (isIntegralRep!Target && isFloatingRep!Source)
{
    // Research contract only: finite/range/fraction classification.
    // Public floating exactness semantics remain deliberately undecided.
    if (value != value)
        return ConversionResult!Target(ConversionStatus.overflow, Target.init);

    const asReal = cast(real) value;
    if (asReal < cast(real) Target.min || asReal > cast(real) Target.max)
        return ConversionResult!Target(ConversionStatus.overflow, Target.init);

    const truncated = cast(Target) value;
    if (cast(Source) truncated != value)
        return ConversionResult!Target(ConversionStatus.inexact, Target.init);

    return ConversionResult!Target(ConversionStatus.exact, truncated);
}

@safe pure nothrow @nogc
Target floatingScaleRep(Target, Source)(
    Source value,
    long num,
    long den)
if (isFloatingRep!Target && isFloatingRep!Source)
{
    return cast(Target)(cast(real) value * cast(real) num / cast(real) den);
}

unittest
{
    // integral -> integral
    enum i1 = checkedIntegralScale!int(1L, 1000, 1);
    static assert(i1.status == ConversionStatus.exact && i1.value == 1000);

    enum i2 = checkedIntegralScale!int(1L, 1, 1000);
    static assert(i2.status == ConversionStatus.inexact);

    enum i3 = checkedIntegralScale!int(cast(long) int.max + 1L, 1, 1);
    static assert(i3.status == ConversionStatus.overflow);

    enum l1 = checkedIntegralScale!long(int.max, 1, 1);
    static assert(l1.status == ConversionStatus.exact && l1.value == int.max);

    // integral -> floating
    enum f1 = integralToFloating!float(1L, 1, 2);
    enum d1 = integralToFloating!double(1L, 381, 1250);
    enum r1 = integralToFloating!real(1L, 1200, 3937);
    static assert(f1 > 0.4999f && f1 < 0.5001f);
    static assert(d1 > 0.304799999999 && d1 < 0.304800000001);
    static assert(r1 > cast(real)0.3048006095L
        && r1 < cast(real)0.3048006097L);

    // floating -> integral
    enum fi1 = checkedFloatingToIntegral!int(42.0);
    enum fi2 = checkedFloatingToIntegral!int(42.5);
    enum fi3 = checkedFloatingToIntegral!int(cast(double) int.max + 1.0);
    static assert(fi1.status == ConversionStatus.exact && fi1.value == 42);
    static assert(fi2.status == ConversionStatus.inexact);
    static assert(fi3.status == ConversionStatus.overflow);

    // floating -> floating
    enum ff1 = floatingScaleRep!double(1.0f, 1000, 1);
    enum ff2 = floatingScaleRep!real(1.0, 381, 1250);
    static assert(ff1 == 1000.0);
    static assert(ff2 > cast(real)0.304799999999L
        && ff2 < cast(real)0.304800000001L);
}
