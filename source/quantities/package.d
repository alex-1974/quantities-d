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

    enum integralCanonical = 42L.quantity!(Length, Metre);
    static assert(integralCanonical.canonicalValue == 42L);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
    static assert(Quantity!(Length, long).sizeof == long.sizeof);
}
