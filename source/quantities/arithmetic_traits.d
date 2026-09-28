module quantities.arithmetic_traits;

import quantities.dimension : MultiplyDimension;
import quantities.traits : isQuantitySpec;

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



private template ForwardProductResult(Lhs, Rhs)
{
    static if (__traits(hasMember, Lhs, "ProductWith"))
        alias ForwardProductResult = Lhs.ProductWith!Rhs;
    else
        alias ForwardProductResult = void;
}

private template ReverseProductResult(Lhs, Rhs)
{
    static if (__traits(hasMember, Rhs, "ProductFromLeft"))
        alias ReverseProductResult = Rhs.ProductFromLeft!Lhs;
    else
        alias ReverseProductResult = void;
}

/// Semantic result Spec for Quantity multiplication.
///
/// A relation may be owned by the left operand through ProductWith!Rhs or by
/// the right operand through ProductFromLeft!Lhs. If both hooks exist they
/// must agree. The selected result must be a valid Quantity Spec whose
/// dimension is exactly the mathematical product dimension.
template ProductResult(Lhs, Rhs)
{
    alias Forward = ForwardProductResult!(Lhs, Rhs);
    alias Reverse = ReverseProductResult!(Lhs, Rhs);

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
        alias ProductResult = void;
    else
    {
        static assert(isQuantitySpec!Candidate,
            "Quantity product relation must resolve to a valid Quantity Spec.");
        static assert(is(
            Candidate.Dimension ==
            MultiplyDimension!(Lhs.Dimension, Rhs.Dimension)),
            "Quantity product ResultSpec has the wrong physical Dimension.");
        alias ProductResult = Candidate;
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
    static assert(is(ProductResult!(Length, Length) == Area));
    return true;
}()));

static assert(is(AddResult!(Additive, Additive) == Additive));
static assert(is(SubResult!(Additive, Additive) == Additive));
static assert(is(AddResult!(Plain, Plain) == void));
static assert(is(SubResult!(Plain, Plain) == void));
static assert(is(AddResult!(Additive, Plain) == void));
