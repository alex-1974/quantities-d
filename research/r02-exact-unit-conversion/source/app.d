module app;

struct Ratio(long Num, long Den)
{
    static assert(Den != 0);

    enum long numerator = Num;
    enum long denominator = Den;
}

alias MetreScale = Ratio!(1, 1);
alias KilometreScale = Ratio!(1000, 1);
alias InternationalFootScale = Ratio!(381, 1250);
alias USSurveyFootScale = Ratio!(1200, 3937);

static assert(MetreScale.numerator == 1);
static assert(KilometreScale.numerator == 1000);
static assert(InternationalFootScale.numerator == 381);
static assert(InternationalFootScale.denominator == 1250);
static assert(USSurveyFootScale.numerator == 1200);
static assert(USSurveyFootScale.denominator == 3937);

// Exact cross-unit relationship, still entirely integral:
//
// international foot / US survey foot
// = (381/1250) / (1200/3937)
// = (381 * 3937) / (1250 * 1200)
// = 1_499_997 / 1_500_000
//
// The ratio is intentionally not reduced here. A later probe will investigate
// GCD reduction and overflow-safe composition before this becomes design.
enum long footCrossNumerator = 381L * 3937L;
enum long footCrossDenominator = 1250L * 1200L;

static assert(footCrossNumerator == 1_499_997L);
static assert(footCrossDenominator == 1_500_000L);

// The definitions are not interchangeable even though their decimal values
// are close.
static assert(
    InternationalFootScale.numerator * USSurveyFootScale.denominator
        != USSurveyFootScale.numerator
            * InternationalFootScale.denominator);

void main()
{
}


// ---------------------------------------------------------------------------
// Probe 2: normalization and cross-cancelled exact composition.
// ---------------------------------------------------------------------------

@safe pure nothrow @nogc
long absLong(long value)
{
    return value < 0 ? -value : value;
}

@safe pure nothrow @nogc
long gcd(long a, long b)
{
    a = absLong(a);
    b = absLong(b);

    while (b != 0)
    {
        const remainder = a % b;
        a = b;
        b = remainder;
    }

    return a;
}

struct NormalizedRatio(long Num, long Den)
{
    static assert(Den != 0);

private:
    enum long sign = Den < 0 ? -1 : 1;
    enum long positiveDen = Den * sign;
    enum long signedNum = Num * sign;
    enum long divisor = gcd(signedNum, positiveDen);

public:
    enum long numerator = signedNum / divisor;
    enum long denominator = positiveDen / divisor;
}

alias ReducedFootCross = NormalizedRatio!(1_499_997, 1_500_000);

static assert(ReducedFootCross.numerator == 499_999);
static assert(ReducedFootCross.denominator == 500_000);

template MultiplyRatio(
    long ANum,
    long ADen,
    long BNum,
    long BDen)
{
    static assert(ADen != 0);
    static assert(BDen != 0);

private:
    // Cross-cancel before multiplication:
    //
    //   (a/b) * (c/d)
    //
    // reduce a against d, and c against b. This lowers intermediate magnitude
    // and therefore lowers avoidable overflow risk.
    enum long g1 = gcd(ANum, BDen);
    enum long g2 = gcd(BNum, ADen);

    enum long a = ANum / g1;
    enum long d = BDen / g1;
    enum long c = BNum / g2;
    enum long b = ADen / g2;

public:
    alias Result = NormalizedRatio!(a * c, b * d);
}

alias FootToMetreThenMetreToFoot =
    MultiplyRatio!(381, 1250, 1250, 381).Result;

static assert(FootToMetreThenMetreToFoot.numerator == 1);
static assert(FootToMetreThenMetreToFoot.denominator == 1);

// Deliberately large factors that would create a much larger naive
// intermediate product, while cross-cancellation reduces them first.
alias CrossCancelledLarge =
    MultiplyRatio!(
        3_000_000_000L, 7,
        7, 3_000_000_000L).Result;

static assert(CrossCancelledLarge.numerator == 1);
static assert(CrossCancelledLarge.denominator == 1);


// ---------------------------------------------------------------------------
// Probe 3: checked multiplication after cross-cancellation.
//
// Cross-cancellation lowers intermediate magnitude, but it does not prove that
// the remaining numerator and denominator products fit in long. The operation
// therefore needs an explicit representability check before multiplication.
// ---------------------------------------------------------------------------

enum long longMax = long.max;

@safe pure nothrow @nogc
bool canMultiplyNonNegative(long a, long b)
{
    assert(a >= 0);
    assert(b >= 0);

    return a == 0 || b <= longMax / a;
}

static assert(canMultiplyNonNegative(0, longMax));
static assert(canMultiplyNonNegative(1, longMax));
static assert(canMultiplyNonNegative(longMax, 1));
static assert(!canMultiplyNonNegative(longMax, 2));
static assert(!canMultiplyNonNegative(longMax / 2 + 1, 2));

template CheckedMultiplyRatio(
    long ANum,
    long ADen,
    long BNum,
    long BDen)
{
    static assert(ANum >= 0, "probe currently covers non-negative scales");
    static assert(BNum >= 0, "probe currently covers non-negative scales");
    static assert(ADen > 0);
    static assert(BDen > 0);

private:
    enum long g1 = gcd(ANum, BDen);
    enum long g2 = gcd(BNum, ADen);

    enum long a = ANum / g1;
    enum long d = BDen / g1;
    enum long c = BNum / g2;
    enum long b = ADen / g2;

    static assert(
        canMultiplyNonNegative(a, c),
        "ratio numerator multiplication is not representable in long");

    static assert(
        canMultiplyNonNegative(b, d),
        "ratio denominator multiplication is not representable in long");

public:
    alias Result = NormalizedRatio!(a * c, b * d);
}

alias CheckedFootIdentity =
    CheckedMultiplyRatio!(381, 1250, 1250, 381).Result;

static assert(CheckedFootIdentity.numerator == 1);
static assert(CheckedFootIdentity.denominator == 1);

// This case is safe only because cross-cancellation runs before the checked
// multiplication.
alias CheckedLargeIdentity =
    CheckedMultiplyRatio!(
        3_000_000_000L, 7,
        7, 3_000_000_000L).Result;

static assert(CheckedLargeIdentity.numerator == 1);
static assert(CheckedLargeIdentity.denominator == 1);

// A genuinely unrepresentable reduced numerator must be rejected rather than
// silently overflowing at compile time.
static assert(!__traits(compiles,
{
    alias TooLarge =
        CheckedMultiplyRatio!(longMax, 1, 2, 1).Result;
    enum forceInstantiation = TooLarge.numerator;
}));


// ---------------------------------------------------------------------------
// Probe 4: value conversion policy.
//
// First policy slice:
// - integral -> integral conversion succeeds only when the mathematical result
//   is exactly representable in long;
// - inexact division is reported, never silently truncated;
// - overflow is reported, never silently wrapped;
// - floating conversion keeps the unit ratio exact until the final arithmetic.
// ---------------------------------------------------------------------------

enum ConversionStatus
{
    exact,
    inexact,
    overflow,
}

struct LongConversion
{
    ConversionStatus status;
    long value;
}

@safe pure nothrow @nogc
LongConversion convertLongByRatio(
    long value,
    long numerator,
    long denominator)
{
    assert(numerator >= 0);
    assert(denominator > 0);
    assert(value >= 0); // first probe slice; signed values follow separately

    // Reduce the input value against the denominator before multiplication.
    // This both exposes exact divisibility and minimizes intermediate size.
    const common = gcd(value, denominator);
    const reducedValue = value / common;
    const reducedDenominator = denominator / common;

    if (reducedDenominator != 1)
    {
        return LongConversion(ConversionStatus.inexact, 0);
    }

    if (!canMultiplyNonNegative(reducedValue, numerator))
    {
        return LongConversion(ConversionStatus.overflow, 0);
    }

    return LongConversion(
        ConversionStatus.exact,
        reducedValue * numerator);
}

// metre -> kilometre: ratio 1/1000
enum oneThousandMetresToKilometres =
    convertLongByRatio(1000, 1, 1000);
static assert(oneThousandMetresToKilometres.status
    == ConversionStatus.exact);
static assert(oneThousandMetresToKilometres.value == 1);

enum oneMetreToKilometres =
    convertLongByRatio(1, 1, 1000);
static assert(oneMetreToKilometres.status
    == ConversionStatus.inexact);

// kilometre -> metre: ratio 1000/1
enum twoKilometresToMetres =
    convertLongByRatio(2, 1000, 1);
static assert(twoKilometresToMetres.status
    == ConversionStatus.exact);
static assert(twoKilometresToMetres.value == 2000);

enum overflowingKilometresToMetres =
    convertLongByRatio(longMax, 1000, 1);
static assert(overflowingKilometresToMetres.status
    == ConversionStatus.overflow);

// Exact foot definitions exercise non-decimal rational conversion.
//
// 1250 international feet = 381 metres exactly.
enum internationalFeetToMetres =
    convertLongByRatio(1250, 381, 1250);
static assert(internationalFeetToMetres.status
    == ConversionStatus.exact);
static assert(internationalFeetToMetres.value == 381);

// 3937 US survey feet = 1200 metres exactly.
enum surveyFeetToMetres =
    convertLongByRatio(3937, 1200, 3937);
static assert(surveyFeetToMetres.status
    == ConversionStatus.exact);
static assert(surveyFeetToMetres.value == 1200);

// One foot cannot be represented as an integral number of metres.
enum oneInternationalFootToMetres =
    convertLongByRatio(1, 381, 1250);
static assert(oneInternationalFootToMetres.status
    == ConversionStatus.inexact);

@safe pure nothrow @nogc
double convertDoubleByRatio(
    double value,
    long numerator,
    long denominator)
{
    return value * cast(double) numerator / cast(double) denominator;
}

enum double internationalFootInMetres =
    convertDoubleByRatio(1.0, 381, 1250);
static assert(internationalFootInMetres == 0.3048);

enum double surveyFootInMetres =
    convertDoubleByRatio(1.0, 1200, 3937);

static assert(surveyFootInMetres != internationalFootInMetres);


// ---------------------------------------------------------------------------
// Probe 5: signed integral conversion including long.min.
//
// Do not take abs(long.min): its positive magnitude is not representable in
// long. Carry magnitude as ulong and apply the sign only after exact rational
// conversion and range checking.
// ---------------------------------------------------------------------------

@safe pure nothrow @nogc
ulong unsignedMagnitude(long value)
{
    if (value >= 0)
    {
        return cast(ulong) value;
    }

    // -(value + 1) is representable in long even for long.min.
    return cast(ulong) (-(value + 1)) + 1UL;
}

static assert(unsignedMagnitude(0) == 0UL);
static assert(unsignedMagnitude(1) == 1UL);
static assert(unsignedMagnitude(-1) == 1UL);
static assert(unsignedMagnitude(long.min) == (1UL << 63));
static assert(unsignedMagnitude(long.max) == cast(ulong) long.max);

@safe pure nothrow @nogc
ulong gcdUnsigned(ulong a, ulong b)
{
    while (b != 0)
    {
        const remainder = a % b;
        a = b;
        b = remainder;
    }

    return a;
}

enum ulong positiveLongLimit = cast(ulong) long.max;
enum ulong negativeLongMagnitudeLimit = 1UL << 63;

@safe pure nothrow @nogc
LongConversion convertSignedLongByRatio(
    long value,
    ulong numerator,
    ulong denominator)
{
    assert(denominator > 0);

    const bool negative = value < 0;
    const ulong magnitude = unsignedMagnitude(value);

    const ulong common = gcdUnsigned(magnitude, denominator);
    const ulong reducedMagnitude = magnitude / common;
    const ulong reducedDenominator = denominator / common;

    if (reducedDenominator != 1)
    {
        return LongConversion(ConversionStatus.inexact, 0);
    }

    if (numerator != 0
        && reducedMagnitude > ulong.max / numerator)
    {
        return LongConversion(ConversionStatus.overflow, 0);
    }

    const ulong convertedMagnitude = reducedMagnitude * numerator;
    const ulong limit = negative
        ? negativeLongMagnitudeLimit
        : positiveLongLimit;

    if (convertedMagnitude > limit)
    {
        return LongConversion(ConversionStatus.overflow, 0);
    }

    if (!negative)
    {
        return LongConversion(
            ConversionStatus.exact,
            cast(long) convertedMagnitude);
    }

    if (convertedMagnitude == negativeLongMagnitudeLimit)
    {
        return LongConversion(ConversionStatus.exact, long.min);
    }

    return LongConversion(
        ConversionStatus.exact,
        -cast(long) convertedMagnitude);
}

enum negativeTwoKilometresToMetres =
    convertSignedLongByRatio(-2, 1000, 1);
static assert(negativeTwoKilometresToMetres.status
    == ConversionStatus.exact);
static assert(negativeTwoKilometresToMetres.value == -2000);

enum negativeOneMetreToKilometres =
    convertSignedLongByRatio(-1, 1, 1000);
static assert(negativeOneMetreToKilometres.status
    == ConversionStatus.inexact);

enum minIdentity =
    convertSignedLongByRatio(long.min, 1, 1);
static assert(minIdentity.status == ConversionStatus.exact);
static assert(minIdentity.value == long.min);

enum minHalved =
    convertSignedLongByRatio(long.min, 1, 2);
static assert(minHalved.status == ConversionStatus.exact);
static assert(minHalved.value == long.min / 2);

enum minDoubled =
    convertSignedLongByRatio(long.min, 2, 1);
static assert(minDoubled.status == ConversionStatus.overflow);

enum maxIdentity =
    convertSignedLongByRatio(long.max, 1, 1);
static assert(maxIdentity.status == ConversionStatus.exact);
static assert(maxIdentity.value == long.max);

enum maxDoubled =
    convertSignedLongByRatio(long.max, 2, 1);
static assert(maxDoubled.status == ConversionStatus.overflow);

// Exact negative non-decimal unit conversion.
enum negativeInternationalFeetToMetres =
    convertSignedLongByRatio(-1250, 381, 1250);
static assert(negativeInternationalFeetToMetres.status
    == ConversionStatus.exact);
static assert(negativeInternationalFeetToMetres.value == -381);


// ---------------------------------------------------------------------------
// Probe 6: caller-visible conversion intentions.
//
// The same exact rational unit relationship is exposed through three distinct
// caller intentions. These names are research vocabulary, not proposed API.
// ---------------------------------------------------------------------------

enum RoundingMode
{
    towardZero,
    floor,
    ceiling,
    nearestTiesAwayFromZero,
}

struct RoundedLongConversion
{
    ConversionStatus status;
    long value;
}

@safe pure nothrow @nogc
RoundedLongConversion roundSignedLongByRatio(
    long value,
    ulong numerator,
    ulong denominator,
    RoundingMode mode)
{
    assert(denominator > 0);

    const bool negative = value < 0;
    const ulong magnitude = unsignedMagnitude(value);

    if (numerator != 0 && magnitude > ulong.max / numerator)
    {
        return RoundedLongConversion(ConversionStatus.overflow, 0);
    }

    const ulong scaled = magnitude * numerator;
    const ulong quotient = scaled / denominator;
    const ulong remainder = scaled % denominator;

    ulong roundedMagnitude = quotient;

    if (remainder != 0)
    {
        final switch (mode)
        {
            case RoundingMode.towardZero:
                break;

            case RoundingMode.floor:
                if (negative)
                {
                    ++roundedMagnitude;
                }
                break;

            case RoundingMode.ceiling:
                if (!negative)
                {
                    ++roundedMagnitude;
                }
                break;

            case RoundingMode.nearestTiesAwayFromZero:
                // Avoid 2 * remainder, which itself could overflow.
                if (remainder > denominator / 2
                    || (denominator % 2 == 0
                        && remainder == denominator / 2))
                {
                    ++roundedMagnitude;
                }
                break;
        }
    }

    const ulong limit = negative
        ? negativeLongMagnitudeLimit
        : positiveLongLimit;

    if (roundedMagnitude > limit)
    {
        return RoundedLongConversion(ConversionStatus.overflow, 0);
    }

    long result;
    if (!negative)
    {
        result = cast(long) roundedMagnitude;
    }
    else if (roundedMagnitude == negativeLongMagnitudeLimit)
    {
        result = long.min;
    }
    else
    {
        result = -cast(long) roundedMagnitude;
    }

    return RoundedLongConversion(
        remainder == 0 ? ConversionStatus.exact : ConversionStatus.inexact,
        result);
}

// checked/loss-aware: preserve the status without choosing rounding.
enum checkedOneMetreToKilometres =
    convertSignedLongByRatio(1, 1, 1000);
static assert(checkedOneMetreToKilometres.status
    == ConversionStatus.inexact);

// exact-required can be expressed as a compile-time contract for compile-time
// values. A runtime API would need an explicit failure carrier/contract.
template ExactRequiredLong(
    long Value,
    ulong Numerator,
    ulong Denominator)
{
    enum conversion =
        convertSignedLongByRatio(Value, Numerator, Denominator);
    static assert(
        conversion.status == ConversionStatus.exact,
        "conversion is not exactly representable");
    enum long result = conversion.value;
}

static assert(ExactRequiredLong!(1000, 1, 1000).result == 1);

static assert(!__traits(compiles,
{
    enum rejected = ExactRequiredLong!(1, 1, 1000).result;
}));

// explicit-rounded: same 1 m -> km conversion, four deliberate policies.
enum oneMetreTowardZero =
    roundSignedLongByRatio(1, 1, 1000, RoundingMode.towardZero);
static assert(oneMetreTowardZero.status == ConversionStatus.inexact);
static assert(oneMetreTowardZero.value == 0);

enum oneMetreFloor =
    roundSignedLongByRatio(1, 1, 1000, RoundingMode.floor);
static assert(oneMetreFloor.value == 0);

enum oneMetreCeiling =
    roundSignedLongByRatio(1, 1, 1000, RoundingMode.ceiling);
static assert(oneMetreCeiling.value == 1);

enum negativeOneMetreFloor =
    roundSignedLongByRatio(-1, 1, 1000, RoundingMode.floor);
static assert(negativeOneMetreFloor.value == -1);

enum negativeOneMetreCeiling =
    roundSignedLongByRatio(-1, 1, 1000, RoundingMode.ceiling);
static assert(negativeOneMetreCeiling.value == 0);

// Tie behavior is explicit: +/- 0.5 rounds away from zero.
enum positiveTie =
    roundSignedLongByRatio(1, 1, 2,
        RoundingMode.nearestTiesAwayFromZero);
static assert(positiveTie.value == 1);

enum negativeTie =
    roundSignedLongByRatio(-1, 1, 2,
        RoundingMode.nearestTiesAwayFromZero);
static assert(negativeTie.value == -1);

// Exact conversions remain exact regardless of the selected rounding policy.
enum exactRoundedPath =
    roundSignedLongByRatio(2000, 1, 1000, RoundingMode.floor);
static assert(exactRoundedPath.status == ConversionStatus.exact);
static assert(exactRoundedPath.value == 2);
