module quantities.arithmetic_traits;

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

private struct Additive
{
    enum closedAdditiveValue = true;
}

private struct Plain {}

static assert(hasClosedAdditiveValue!Additive);
static assert(!hasClosedAdditiveValue!Plain);
static assert(is(AddResult!(Additive, Additive) == Additive));
static assert(is(SubResult!(Additive, Additive) == Additive));
static assert(is(AddResult!(Plain, Plain) == void));
static assert(is(SubResult!(Plain, Plain) == void));
static assert(is(AddResult!(Additive, Plain) == void));
