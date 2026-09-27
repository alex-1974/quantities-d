module quantities.traits;

template isUnit(Unit)
{
    static if (!__traits(hasMember, Unit, "Dimension"))
        enum isUnit = false;
    else static if (!__traits(hasMember, Unit, "Scale"))
        enum isUnit = false;
    else static if (!__traits(hasMember, Unit.Scale, "numerator"))
        enum isUnit = false;
    else static if (!__traits(hasMember, Unit.Scale, "denominator"))
        enum isUnit = false;
    else
        enum isUnit = Unit.Scale.denominator > 0;
}

template isQuantitySpec(Spec)
{
    static if (!__traits(hasMember, Spec, "Dimension"))
        enum isQuantitySpec = false;
    else static if (!__traits(hasMember, Spec, "CanonicalUnit"))
        enum isQuantitySpec = false;
    else static if (!isUnit!(Spec.CanonicalUnit))
        enum isQuantitySpec = false;
    else
        enum isQuantitySpec =
            is(Spec.Dimension == Spec.CanonicalUnit.Dimension);
}
