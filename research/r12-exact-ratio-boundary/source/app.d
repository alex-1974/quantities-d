module app;

@safe pure nothrow @nogc
ulong magnitude(long value)
{
    if (value >= 0)
        return cast(ulong) value;

    // -(value + 1) is representable even for long.min.
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

struct ExactRatio(long Num, long Den)
{
    static assert(Den != 0, "ExactRatio denominator must not be zero.");
    static assert(Den != long.min,
        "ExactRatio denominator long.min cannot be normalized to a positive long.");

private:
    enum bool negative = (Num < 0) != (Den < 0);
    enum ulong nMagnitude = magnitude(Num);
    enum ulong dMagnitude = magnitude(Den);
    enum ulong divisor = gcdUnsigned(nMagnitude, dMagnitude);
    enum ulong reducedN = divisor == 0 ? 0 : nMagnitude / divisor;
    enum ulong reducedD = divisor == 0 ? 1 : dMagnitude / divisor;

    static assert(reducedD <= cast(ulong) long.max,
        "ExactRatio normalized denominator is not representable in long.");
    static assert(
        negative
            ? reducedN <= cast(ulong) long.max + 1UL
            : reducedN <= cast(ulong) long.max,
        "ExactRatio normalized numerator is not representable in long.");

    enum long signedNumerator =
        reducedN == 0 ? 0
        : negative && reducedN == cast(ulong) long.max + 1UL
            ? long.min
            : negative
                ? -cast(long) reducedN
                : cast(long) reducedN;

public:
    enum long numerator = signedNumerator;
    enum long denominator = cast(long) reducedD;
}

alias Half = ExactRatio!(1, 2);
alias ReducedHalf = ExactRatio!(2, 4);
alias SignNormalized = ExactRatio!(-2, -4);
alias NegativeHalfA = ExactRatio!(-1, 2);
alias NegativeHalfB = ExactRatio!(1, -2);
alias Zero = ExactRatio!(0, -37);
alias MinNumerator = ExactRatio!(long.min, 1);
alias MinReduced = ExactRatio!(long.min, 2);

alias InternationalFoot = ExactRatio!(381, 1250);
alias USSurveyFoot = ExactRatio!(1200, 3937);

static assert(Half.numerator == 1 && Half.denominator == 2);
static assert(ReducedHalf.numerator == 1 && ReducedHalf.denominator == 2);
static assert(SignNormalized.numerator == 1 && SignNormalized.denominator == 2);
static assert(NegativeHalfA.numerator == -1 && NegativeHalfA.denominator == 2);
static assert(NegativeHalfB.numerator == -1 && NegativeHalfB.denominator == 2);
static assert(Zero.numerator == 0 && Zero.denominator == 1);
static assert(MinNumerator.numerator == long.min && MinNumerator.denominator == 1);
static assert(MinReduced.numerator == long.min / 2 && MinReduced.denominator == 1);

static assert(InternationalFoot.numerator == 381);
static assert(InternationalFoot.denominator == 1250);
static assert(USSurveyFoot.numerator == 1200);
static assert(USSurveyFoot.denominator == 3937);

static assert(!__traits(compiles, ExactRatio!(1, 0)));
static assert(!__traits(compiles, ExactRatio!(1, long.min)));

void main() {}
