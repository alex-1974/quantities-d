module r15_ab_diagnostics;

import quantities.ratio : ExactRatio;

struct LengthDimension {}
struct TimeDimension {}

// A: explicit declaration baseline.
struct AGood {
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1000, 1);
}

// B: template declaration.
template Unit(Dimension_, long N, long D)
{
    static assert(D != 0, "Unit scale denominator must not be zero");

    struct Unit
    {
        alias Dimension = Dimension_;
        alias Scale = ExactRatio!(N, D);
    }
}

alias BGood = Unit!(LengthDimension, 1000, 1);

static assert(__traits(compiles, AGood.Dimension));
static assert(__traits(compiles, BGood.Dimension));

// Preserve evidence about the public/compiler-visible type identity.
pragma(msg, "A type: ", AGood.stringof);
pragma(msg, "B alias: ", BGood.stringof);
pragma(msg, "B instantiated type: ", Unit!(LengthDimension, 1000, 1).stringof);

void main() {}
