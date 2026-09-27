module quantities.length;

import quantities.ratio : ExactRatio;

/// Linear length dimension.
struct LengthDimension {}

/// Metre, the canonical unit of Length.
struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1);
}

/// Generic linear length quantity specification.
///
/// More specific semantic specifications such as Distance, Radius, or Height
/// are intentionally deferred until consumer evidence justifies them.
struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

/// Kilometre: exactly 1000 metres.
struct Kilometre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1000, 1);
}

/// International foot: exactly 0.3048 metres.
struct InternationalFoot
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(381, 1250);
}

/// US survey foot: exactly 1200 / 3937 metres.
struct USSurveyFoot
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1200, 3937);
}

private template AliasSeq(T...)
{
    alias AliasSeq = T;
}

/// M2 compile-time family of supported length units.
alias LengthUnits = AliasSeq!(
    Metre,
    Kilometre,
    InternationalFoot,
    USSurveyFoot
);

static foreach (Unit; LengthUnits)
{
    static assert(is(Unit.Dimension == LengthDimension));
    static assert(Unit.Scale.denominator > 0);
}

static assert(is(Length.CanonicalUnit == Metre));
static assert(is(Metre.Scale == ExactRatio!(1, 1)));
static assert(is(Kilometre.Scale == ExactRatio!(1000, 1)));
static assert(is(InternationalFoot.Scale == ExactRatio!(381, 1250)));
static assert(is(USSurveyFoot.Scale == ExactRatio!(1200, 3937)));
