module r15_negative_b;

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

version (BadZeroDenominator)
alias BadZeroDenominator = Unit!(LengthDimension, 1, 0);

// The template makes Dimension mandatory syntactically. This case probes the
// diagnostic produced when a non-type/non-dimension-like argument is supplied.
version (BadDimensionArgument)
alias BadDimensionArgument = Unit!(42, 1, 1);

void main() {}
