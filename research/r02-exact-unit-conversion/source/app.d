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
