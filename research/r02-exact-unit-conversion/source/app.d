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
