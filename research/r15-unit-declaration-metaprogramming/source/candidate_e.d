module r15_candidate_e;

import quantities.ratio : ExactRatio;

struct LengthDimension {}

// E1: mixin template injects the structural Unit contract into a normal,
// explicitly named public struct.
mixin template LinearUnit(alias Dimension_, long N, long D)
{
    alias Dimension = Dimension_;
    alias Scale = ExactRatio!(N, D);
}

struct Metre {
    mixin LinearUnit!(LengthDimension, 1, 1);
}
struct Kilometre {
    mixin LinearUnit!(LengthDimension, 1000, 1);
}
struct Centimetre {
    mixin LinearUnit!(LengthDimension, 1, 100);
}
struct Millimetre {
    mixin LinearUnit!(LengthDimension, 1, 1000);
}
struct InternationalFoot {
    mixin LinearUnit!(LengthDimension, 381, 1250);
}
struct USSurveyFoot {
    mixin LinearUnit!(LengthDimension, 1200, 3937);
}

template AliasSeq(T...) { alias AliasSeq = T; }

alias LengthUnits = AliasSeq!(
    Metre, Kilometre, Centimetre, Millimetre,
    InternationalFoot, USSurveyFoot
);

static foreach (U; LengthUnits)
{
    static assert(is(U.Dimension == LengthDimension));
    static assert(U.Scale.denominator > 0);
}

static foreach (From; LengthUnits)
    static foreach (To; LengthUnits)
        static assert(is(From.Dimension == To.Dimension));

pragma(msg, "E1 metre type: ", Metre.stringof);
pragma(msg, "E1 kilometre type: ", Kilometre.stringof);
pragma(msg, "E1 kilometre scale: ", Kilometre.Scale.stringof);

// E2: string mixin creates a declaration from text. Keep it isolated from the
// reference family so its only possible benefit can be inspected directly.
string defineUnit(string name, string dimension, long n, long d)()
{
    import std.conv : to;
    return "struct " ~ name ~
        " { alias Dimension = " ~ dimension ~
        "; alias Scale = ExactRatio!(" ~ n.to!string ~ ", " ~ d.to!string ~
        "); }";
}

mixin(defineUnit!("StringMixinKilometre", "LengthDimension", 1000, 1));

static assert(is(StringMixinKilometre.Dimension == LengthDimension));
static assert(is(StringMixinKilometre.Scale == ExactRatio!(1000, 1)));
pragma(msg, "E2 generated type: ", StringMixinKilometre.stringof);

void main() {}
