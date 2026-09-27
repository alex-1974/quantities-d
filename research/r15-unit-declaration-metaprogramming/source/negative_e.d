module r15_negative_e;

import quantities.ratio : ExactRatio;

struct LengthDimension {}

mixin template LinearUnit(alias Dimension_, long N, long D)
{
    alias Dimension = Dimension_;
    alias Scale = ExactRatio!(N, D);
}

version (MixinBadZeroDenominator)
struct MixinBadZeroDenominator
{
    mixin LinearUnit!(LengthDimension, 1, 0);
}

string defineUnit(string name, string dimension, long n, long d)()
{
    import std.conv : to;
    return "struct " ~ name ~
        " { alias Dimension = " ~ dimension ~
        "; alias Scale = ExactRatio!(" ~ n.to!string ~ ", " ~ d.to!string ~
        "); }";
}

version (StringMixinBadZeroDenominator)
mixin(defineUnit!(
    "StringMixinBadZeroDenominator",
    "LengthDimension",
    1,
    0
));

void main() {}
