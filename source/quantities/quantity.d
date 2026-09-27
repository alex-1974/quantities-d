module quantities.quantity;

import quantities.traits : isQuantitySpec, isUnit;

private template isFloatingRep(Rep)
{
    enum isFloatingRep =
        is(Rep == float) || is(Rep == double) || is(Rep == real);
}

struct Quantity(Spec, Rep)
{
    static assert(isQuantitySpec!Spec,
        "Quantity Spec must define Dimension and a valid CanonicalUnit with the same Dimension.");

private:
    Rep canonical_;

    @safe pure nothrow @nogc
    this(Rep canonical)
    {
        canonical_ = canonical;
    }

    @safe pure nothrow @nogc
    static Quantity fromCanonical(Rep canonical)
    {
        return Quantity(canonical);
    }

public:
    @safe pure nothrow @nogc
    Rep canonicalValue() const
    {
        return canonical_;
    }
}

@safe pure nothrow @nogc
auto quantity(Spec, Unit, Rep)(Rep value)
{
    static assert(isQuantitySpec!Spec,
        "quantity: Spec must define Dimension and a valid CanonicalUnit.");
    static assert(isUnit!Unit,
        "quantity: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "quantity: Spec and Unit must have the same Dimension.");

    static if (is(Unit == Spec.CanonicalUnit))
    {
        return Quantity!(Spec, Rep).fromCanonical(value);
    }
    else static if (isFloatingRep!Rep)
    {
        const canonical = cast(Rep)(
            value
            * cast(Rep) Unit.Scale.numerator
            * cast(Rep) Spec.CanonicalUnit.Scale.denominator
            / cast(Rep) Unit.Scale.denominator
            / cast(Rep) Spec.CanonicalUnit.Scale.numerator);
        return Quantity!(Spec, Rep).fromCanonical(canonical);
    }
    else
    {
        static assert(false,
            "quantity: non-canonical Unit construction for integral Rep requires checked conversion and is not yet available.");
    }
}

@safe pure nothrow @nogc
auto inUnit(Unit, Spec, Rep)(Quantity!(Spec, Rep) value)
{
    static assert(isUnit!Unit,
        "inUnit: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "inUnit: Quantity Spec and Unit must have the same Dimension.");

    static if (is(Unit == Spec.CanonicalUnit))
    {
        return value.canonicalValue;
    }
    else static if (isFloatingRep!Rep)
    {
        return cast(Rep)(
            value.canonicalValue
            * cast(Rep) Spec.CanonicalUnit.Scale.numerator
            * cast(Rep) Unit.Scale.denominator
            / cast(Rep) Spec.CanonicalUnit.Scale.denominator
            / cast(Rep) Unit.Scale.numerator);
    }
    else
    {
        static assert(false,
            "inUnit: non-canonical Unit extraction for integral Rep requires checked conversion and is not yet available.");
    }
}
