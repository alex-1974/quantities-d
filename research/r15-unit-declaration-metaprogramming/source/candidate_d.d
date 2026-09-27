module r15_candidate_d;

import quantities.ratio : ExactRatio;

struct LengthDimension {}

// Descriptor carries compile-time catalogue data, but is not itself the public
// Unit type.
template UnitDescriptor(alias UnitType_, alias Dimension_, long N, long D)
{
    alias UnitType = UnitType_;
    alias Dimension = Dimension_;
    alias Scale = ExactRatio!(N, D);
}

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

alias MetreDef = UnitDescriptor!(Metre, LengthDimension, 1, 1);
alias KilometreDef = UnitDescriptor!(Kilometre, LengthDimension, 1000, 1);
alias CentimetreDef = UnitDescriptor!(Centimetre, LengthDimension, 1, 100);
alias MillimetreDef = UnitDescriptor!(Millimetre, LengthDimension, 1, 1000);
alias InternationalFootDef =
    UnitDescriptor!(InternationalFoot, LengthDimension, 381, 1250);
alias USSurveyFootDef =
    UnitDescriptor!(USSurveyFoot, LengthDimension, 1200, 3937);

template AliasSeq(T...) { alias AliasSeq = T; }

alias LengthUnitDefs = AliasSeq!(
    MetreDef, KilometreDef, CentimetreDef, MillimetreDef,
    InternationalFootDef, USSurveyFootDef
);

template sameRatio(A, B)
{
    enum sameRatio =
        A.numerator == B.numerator &&
        A.denominator == B.denominator;
}

// Descriptor-driven family validation.
static foreach (Def; LengthUnitDefs)
{
    static assert(is(Def.UnitType.Dimension == Def.Dimension));
    static assert(sameRatio!(Def.UnitType.Scale, Def.Scale));
}

// Descriptor-driven pairwise matrix: the catalogue can enumerate all pairs,
// but no conversion semantics are duplicated here.
static foreach (From; LengthUnitDefs)
{
    static foreach (To; LengthUnitDefs)
    {
        static assert(is(From.Dimension == To.Dimension));
    }
}

pragma(msg, "D public kilometre type: ", Kilometre.stringof);
pragma(msg, "D descriptor alias: ", KilometreDef.stringof);
pragma(msg, "D descriptor unit type: ", KilometreDef.UnitType.stringof);

void main() {}
