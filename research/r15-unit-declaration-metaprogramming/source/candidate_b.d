module r15_candidate_b;

import quantities.ratio : ExactRatio;

struct LengthDimension {}

template Unit(Dimension_, long N, long D)
{
    static assert(D != 0, "Unit scale denominator must not be zero");

    struct Unit
    {
        alias Dimension = Dimension_;
        alias Scale = ExactRatio!(N, D);
    }
}

alias Metre = Unit!(LengthDimension, 1, 1);
alias Kilometre = Unit!(LengthDimension, 1000, 1);
alias Centimetre = Unit!(LengthDimension, 1, 100);
alias Millimetre = Unit!(LengthDimension, 1, 1000);
alias InternationalFoot = Unit!(LengthDimension, 381, 1250);
alias USSurveyFoot = Unit!(LengthDimension, 1200, 3937);

template AliasSeq(T...) { alias AliasSeq = T; }

alias LengthUnits = AliasSeq!(
    Metre, Kilometre, Centimetre, Millimetre,
    InternationalFoot, USSurveyFoot
);

enum isUnit(U) = __traits(compiles, U.Dimension) && __traits(compiles, U.Scale);

static foreach (U; LengthUnits) {
    static assert(isUnit!U);
    static assert(is(U.Dimension == LengthDimension));
}

static assert(Metre.Scale.numerator == 1);
static assert(Metre.Scale.denominator == 1);
static assert(Kilometre.Scale.numerator == 1000);
static assert(Kilometre.Scale.denominator == 1);
static assert(Centimetre.Scale.numerator == 1);
static assert(Centimetre.Scale.denominator == 100);
static assert(Millimetre.Scale.numerator == 1);
static assert(Millimetre.Scale.denominator == 1000);
static assert(InternationalFoot.Scale.numerator == 381);
static assert(InternationalFoot.Scale.denominator == 1250);
static assert(USSurveyFoot.Scale.numerator == 1200);
static assert(USSurveyFoot.Scale.denominator == 3937);

void main() {}
