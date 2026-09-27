module quantities.quantity;

import quantities.traits : isQuantitySpec, isUnit;

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
    package(quantities) static Quantity fromCanonical(Rep canonical)
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
    else
    {
        static assert(false,
            "quantity: non-canonical Unit construction requires checkedQuantity, exactQuantity, or roundedQuantity.");
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
    else
    {
        static assert(false,
            "inUnit: non-canonical Unit extraction requires checkedIn, exactIn, or roundedIn.");
    }
}
