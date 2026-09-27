module r15_negative_a;

import quantities.ratio : ExactRatio;

struct LengthDimension {}

// Compile with -version=BadZeroDenominator to inspect ExactRatio diagnostics.
version (BadZeroDenominator)
struct BadZeroDenominator {
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 0);
}

// Compile with -version=MissingDimension to inspect structural boundary diagnostics.
version (MissingDimension)
struct MissingDimension {
    alias Scale = ExactRatio!(1, 1);
}

void requireUnit(U)()
{
    static assert(__traits(compiles, U.Dimension),
        "Unit must provide Dimension");
    static assert(__traits(compiles, U.Scale),
        "Unit must provide Scale");
}

version (MissingDimension)
enum forceMissingDimension = requireUnit!MissingDimension();

void main() {}
