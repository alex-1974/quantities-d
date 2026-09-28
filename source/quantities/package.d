module quantities;

public import quantities.arithmetic :
    DivisionResult,
    DivisionStatus,
    exactDiv;

public import quantities.conversion :
    ConversionResult,
    ConversionStatus,
    ExactFailure,
    ExactResult,
    RoundingMode,
    checkedIn,
    checkedQuantity,
    exactIn,
    exactQuantity,
    roundedIn,
    roundedQuantity;
public import quantities.quantity : Quantity, inUnit, quantity;
public import quantities.length :
    InternationalFoot,
    Kilometre,
    Length,
    LengthDimension,
    LengthUnits,
    Metre,
    USSurveyFoot;
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

    struct Length
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;
    }

    enum integralCanonical = 42L.quantity!(Length, Metre);
    static assert(integralCanonical.canonicalValue == 42L);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
    static assert(Quantity!(Length, long).sizeof == long.sizeof);
}
