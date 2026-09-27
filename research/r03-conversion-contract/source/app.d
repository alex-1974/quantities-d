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
