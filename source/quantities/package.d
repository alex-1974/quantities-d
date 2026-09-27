module quantities;

public import quantities.quantity : Quantity, inUnit, quantity;
public import quantities.ratio : ExactRatio;
public import quantities.traits : isQuantitySpec, isUnit;

@safe unittest
{
    struct LengthDimension {}

    struct Metre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 1);
    }

    struct Kilometre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1000, 1);
    }

    struct Length
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;
    }

    enum metres = 1.5.quantity!(Length, Kilometre);
    static assert(metres.canonicalValue == 1500.0);
    static assert(metres.inUnit!Kilometre == 1.5);

    enum integralCanonical = 42L.quantity!(Length, Metre);
    static assert(integralCanonical.canonicalValue == 42L);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
    static assert(Quantity!(Length, long).sizeof == long.sizeof);
}
