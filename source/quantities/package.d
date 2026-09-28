module quantities;

public import quantities.arithmetic_traits :
    ExternalProductResultSpec,
    ProductResultSpec;
public import quantities.area : Area, AreaDimension, SquareMetre;
public import quantities.dimension :
    BaseDimension,
    Dimension,
    DimensionTerm,
    Dimensionless,
    DivideDimension,
    MultiplyDimension,
    PowerDimension;
public import quantities.unit :
    DerivedUnit,
    DivideUnit,
    MultiplyUnit,
    PowerUnit;

public import quantities.arithmetic :
    DivisionResult,
    ProductFailure,
    ProductResultValue,
    exactMul,
    product,
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
    LengthDimensionTag,
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
