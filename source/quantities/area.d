module quantities.area;

import quantities.dimension : PowerDimension;
import quantities.length : LengthDimension, Metre;
import quantities.unit : PowerUnit;

/// Area dimension: length squared.
alias AreaDimension = PowerDimension!(LengthDimension, 2);

/// Square metre, the canonical unit of Area.
alias SquareMetre = PowerUnit!(Metre, 2);

/// Generic area quantity specification.
struct Area
{
    alias Dimension = AreaDimension;
    alias CanonicalUnit = SquareMetre;
}

static assert(is(SquareMetre.Dimension == AreaDimension));
static assert(SquareMetre.Scale.numerator == 1);
static assert(SquareMetre.Scale.denominator == 1);
static assert(is(Area.CanonicalUnit == SquareMetre));

@safe unittest
{
    import quantities.dimension : Dimension, DimensionTerm;
    import quantities.length : LengthDimensionTag;
    import quantities.ratio : ExactRatio;
    import quantities.traits : isQuantitySpec, isUnit;
    import quantities.unit : DerivedUnit;

    static assert(is(
        AreaDimension ==
        Dimension!(DimensionTerm!(LengthDimensionTag, 2))));

    static assert(isUnit!SquareMetre);
    static assert(isQuantitySpec!Area);

    // A consumer-defined area unit can reuse the same derived dimension.
    alias SquareKilometre = DerivedUnit!(
        AreaDimension,
        ExactRatio!(1_000_000, 1));
    static assert(is(SquareKilometre.Dimension == AreaDimension));
    static assert(SquareKilometre.Scale.numerator == 1_000_000);
}
