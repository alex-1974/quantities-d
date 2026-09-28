module app;

import std.traits : hasMember;

struct LengthDimension {}
struct Metre {}

struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;

    enum closedAdditiveValue = true;
}

struct Radius
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

struct Elevation
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

template hasClosedAdditiveValue(Spec)
{
    static if (__traits(hasMember, Spec, "closedAdditiveValue"))
        enum hasClosedAdditiveValue =
            is(typeof(Spec.closedAdditiveValue) == bool) &&
            Spec.closedAdditiveValue;
    else
        enum hasClosedAdditiveValue = false;
}

// Research-local future extension hook.
// Default: no explicit relationship.
template ExplicitAddResult(Lhs, Rhs)
{
    alias ExplicitAddResult = void;
}

template ExplicitSubResult(Lhs, Rhs)
{
    static if (is(Lhs == Elevation) && is(Rhs == Elevation))
        alias ExplicitSubResult = Length;
    else
        alias ExplicitSubResult = void;
}

template AddResult(Lhs, Rhs)
{
    alias Explicit = ExplicitAddResult!(Lhs, Rhs);

    static if (!is(Explicit == void))
        alias AddResult = Explicit;
    else static if (is(Lhs == Rhs) && hasClosedAdditiveValue!Lhs)
        alias AddResult = Lhs;
    else
        alias AddResult = void;
}

template SubResult(Lhs, Rhs)
{
    alias Explicit = ExplicitSubResult!(Lhs, Rhs);

    static if (!is(Explicit == void))
        alias SubResult = Explicit;
    else static if (is(Lhs == Rhs) && hasClosedAdditiveValue!Lhs)
        alias SubResult = Lhs;
    else
        alias SubResult = void;
}

static assert(hasClosedAdditiveValue!Length);
static assert(!hasClosedAdditiveValue!Radius);
static assert(!hasClosedAdditiveValue!Elevation);

static assert(is(AddResult!(Length, Length) == Length));
static assert(is(SubResult!(Length, Length) == Length));

static assert(is(AddResult!(Length, Radius) == void));
static assert(is(SubResult!(Length, Radius) == void));

static assert(is(AddResult!(Radius, Radius) == void));
static assert(is(SubResult!(Radius, Radius) == void));

static assert(is(AddResult!(Elevation, Elevation) == void));
static assert(is(SubResult!(Elevation, Elevation) == Length));

// Resolution is semantic only: Rep types are deliberately absent from this
// entire probe.
void main() {}
