module r15_candidate_a;

import quantities.ratio : ExactRatio;

struct LengthDimension {}

struct Metre {
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1);
}
struct Kilometre {
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1000, 1);
}
struct Centimetre {
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 100);
}
struct Millimetre {
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1000);
}
struct InternationalFoot {
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(381, 1250);
}
struct USSurveyFoot {
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1200, 3937);
}

alias LengthUnits = AliasSeq!(
    Metre, Kilometre, Centimetre, Millimetre,
    InternationalFoot, USSurveyFoot
);

template AliasSeq(T...) { alias AliasSeq = T; }

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
