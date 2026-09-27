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

    struct Centimetre
    {
        alias Dimension = LengthDimension;
        alias Scale = ExactRatio!(1, 100);
    }

    struct CentimetreLength
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Centimetre;
    }

    enum metres = 1.5.quantity!(Length, Kilometre);
    static assert(metres.canonicalValue == 1500.0);
    static assert(metres.inUnit!Kilometre == 1.5);

    // CanonicalUnit need not be the Dimension reference unit (scale 1).
    enum centimetres = 1.5.quantity!(CentimetreLength, Metre);
    static assert(centimetres.canonicalValue == 150.0);
    static assert(centimetres.inUnit!Metre == 1.5);

    enum integralCanonical = 42L.quantity!(Length, Metre);
    static assert(integralCanonical.canonicalValue == 42L);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
    static assert(Quantity!(Length, long).sizeof == long.sizeof);
}
