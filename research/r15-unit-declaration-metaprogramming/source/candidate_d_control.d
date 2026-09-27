module r15_candidate_d_control;

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

template AliasSeq(T...) { alias AliasSeq = T; }

alias LengthUnits = AliasSeq!(
    Metre, Kilometre, Centimetre, Millimetre,
    InternationalFoot, USSurveyFoot
);

// The Unit types themselves are the catalogue entries.
static foreach (U; LengthUnits)
{
    static assert(is(U.Dimension == LengthDimension));
    static assert(U.Scale.denominator > 0);
}

// Same 6 x 6 family matrix as candidate D, without descriptor duplication.
static foreach (From; LengthUnits)
{
    static foreach (To; LengthUnits)
    {
        static assert(is(From.Dimension == To.Dimension));
    }
}

pragma(msg, "D-control public kilometre type: ", Kilometre.stringof);
pragma(msg, "D-control catalogue entry: ", LengthUnits[1].stringof);

void main() {}
