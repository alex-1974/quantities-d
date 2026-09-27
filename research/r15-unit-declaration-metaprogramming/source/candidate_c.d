module r15_candidate_c;

import quantities.ratio : ExactRatio;

struct LengthDimension {}

template Pow10Ratio(int Exponent)
{
    static if (Exponent == 0)
    {
        alias Pow10Ratio = ExactRatio!(1, 1);
    }
    else static if (Exponent > 0)
    {
        enum long value = pow10!Exponent;
        alias Pow10Ratio = ExactRatio!(value, 1);
    }
    else
    {
        enum long value = pow10!(-Exponent);
        alias Pow10Ratio = ExactRatio!(1, value);
    }
}

private template pow10(int Exponent)
{
    static assert(Exponent >= 0, "pow10 exponent must be non-negative");

    static if (Exponent == 0)
        enum long pow10 = 1;
    else
    {
        enum long previous = pow10!(Exponent - 1);
        static assert(previous <= long.max / 10,
            "SI prefix scale exceeds ExactRatio long range");
        enum long pow10 = previous * 10;
    }
}

// Public Units remain real named structs. Metaprogramming only derives the
// exact decimal scale.
struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = Pow10Ratio!0;
}

struct Kilometre
{
    alias Dimension = LengthDimension;
    alias Scale = Pow10Ratio!3;
}

struct Centimetre
{
    alias Dimension = LengthDimension;
    alias Scale = Pow10Ratio!(-2);
}

struct Millimetre
{
    alias Dimension = LengthDimension;
    alias Scale = Pow10Ratio!(-3);
}

// Non-SI definitions remain explicit exact ratios.
struct InternationalFoot
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(381, 1250);
}

struct USSurveyFoot
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1200, 3937);
}

template AliasSeq(T...) { alias AliasSeq = T; }

alias LengthUnits = AliasSeq!(
    Metre, Kilometre, Centimetre, Millimetre,
    InternationalFoot, USSurveyFoot
);

static assert(is(Metre.Scale == ExactRatio!(1, 1)));
static assert(is(Kilometre.Scale == ExactRatio!(1000, 1)));
static assert(is(Centimetre.Scale == ExactRatio!(1, 100)));
static assert(is(Millimetre.Scale == ExactRatio!(1, 1000)));
static assert(is(InternationalFoot.Scale == ExactRatio!(381, 1250)));
static assert(is(USSurveyFoot.Scale == ExactRatio!(1200, 3937)));

static assert(Pow10Ratio!0.numerator == 1);
static assert(Pow10Ratio!0.denominator == 1);
static assert(Pow10Ratio!3.numerator == 1000);
static assert(Pow10Ratio!3.denominator == 1);
static assert(Pow10Ratio!(-3).numerator == 1);
static assert(Pow10Ratio!(-3).denominator == 1000);

// Public type identity remains the domain name rather than the scale template.
pragma(msg, "C metre type: ", Metre.stringof);
pragma(msg, "C kilometre type: ", Kilometre.stringof);
pragma(msg, "C kilometre scale: ", Kilometre.Scale.stringof);

void main() {}
