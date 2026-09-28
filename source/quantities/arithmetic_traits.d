module quantities.arithmetic_traits;

import quantities.dimension : MultiplyDimension;
import quantities.traits : isQuantitySpec;
import quantities.unit : DivideUnit, MultiplyUnit;

package(quantities):

template hasClosedAdditiveValue(Spec)
{
    static if (__traits(hasMember, Spec, "closedAdditiveValue"))
        enum hasClosedAdditiveValue =
            is(typeof(Spec.closedAdditiveValue) == bool) &&
            Spec.closedAdditiveValue;
    else
        enum hasClosedAdditiveValue = false;
}

template isScalableValue(Spec)
{
    static if (__traits(hasMember, Spec, "scalableValue"))
        enum isScalableValue =
            is(typeof(Spec.scalableValue) == bool) &&
            Spec.scalableValue;
    else
        enum isScalableValue = false;
}

template AddResult(Lhs, Rhs)
{
    static if (is(Lhs == Rhs) && hasClosedAdditiveValue!Lhs)
        alias AddResult = Lhs;
    else
        alias AddResult = void;
}

template SubResult(Lhs, Rhs)
{
    static if (is(Lhs == Rhs) && hasClosedAdditiveValue!Lhs)
        alias SubResult = Lhs;
    else
        alias SubResult = void;
}




/// Exact scale from the mathematical product unit to ResultSpec's canonical
/// storage unit.
///
/// A value in Lhs.CanonicalUnit * Rhs.CanonicalUnit is multiplied by this
/// ratio before it can be stored as a Quantity!ResultSpec.
template ProductCanonicalRescale(Lhs, Rhs, ResultSpec)
{
    alias MathematicalUnit =
        MultiplyUnit!(Lhs.CanonicalUnit, Rhs.CanonicalUnit);
    alias StorageRatioUnit = DivideUnit!(
        MathematicalUnit,
        ResultSpec.CanonicalUnit);
    alias ProductCanonicalRescale = StorageRatioUnit.Scale;
}

private template ForwardProductResultSpec(Lhs, Rhs)
{
    static if (__traits(hasMember, Lhs, "ProductWith"))
        alias ForwardProductResultSpec = Lhs.ProductWith!Rhs;
    else
        alias ForwardProductResultSpec = void;
}

private template ReverseProductResultSpec(Lhs, Rhs)
{
    static if (__traits(hasMember, Rhs, "ProductFromLeft"))
        alias ReverseProductResultSpec = Rhs.ProductFromLeft!Lhs;
    else
        alias ReverseProductResultSpec = void;
}

/// Semantic result Spec for Quantity multiplication.
///
/// A relation may be owned by the left operand through ProductWith!Rhs or by
/// the right operand through ProductFromLeft!Lhs. If both hooks exist they
/// must agree. The selected result must be a valid Quantity Spec whose
/// dimension is exactly the mathematical product dimension.
template ProductResultSpec(Lhs, Rhs)
{
    alias Forward = ForwardProductResultSpec!(Lhs, Rhs);
    alias Reverse = ReverseProductResultSpec!(Lhs, Rhs);

    static if (!is(Forward == void) && !is(Reverse == void))
    {
        static assert(is(Forward == Reverse),
            "conflicting Quantity product semantic relations");
        alias Candidate = Forward;
    }
    else static if (!is(Forward == void))
        alias Candidate = Forward;
    else static if (!is(Reverse == void))
        alias Candidate = Reverse;
    else
        alias Candidate = void;

    static if (is(Candidate == void))
        alias ProductResultSpec = void;
    else
    {
        static assert(isQuantitySpec!Candidate,
            "Quantity product relation must resolve to a valid Quantity Spec.");
        static assert(is(
            Candidate.Dimension ==
            MultiplyDimension!(Lhs.Dimension, Rhs.Dimension)),
            "Quantity product ResultSpec has the wrong physical Dimension.");
        alias ProductResultSpec = Candidate;
    }
}

private struct Additive
{
    enum closedAdditiveValue = true;
}

private struct Plain {}

static assert(hasClosedAdditiveValue!Additive);
static assert(!hasClosedAdditiveValue!Plain);
static assert(({
    import quantities.area : Area;
    import quantities.length : Length;
    static assert(is(ProductResultSpec!(Length, Length) == Area));
    return true;
}()));

static assert(is(AddResult!(Additive, Additive) == Additive));
static assert(is(SubResult!(Additive, Additive) == Additive));
static assert(is(AddResult!(Plain, Plain) == void));
static assert(is(SubResult!(Plain, Plain) == void));
static assert(is(AddResult!(Additive, Plain) == void));
