module common;

enum ConversionStatus
{
    exact,
    inexact,
    overflow,
    nonFinite
}

enum RoundingMode
{
    towardZero,
    floor,
    ceiling,
    nearestTiesAway
}

struct ConversionResult(T)
{
    T value;
    ConversionStatus status;
}

struct LengthDimension {}

struct Scale(long Numerator, long Denominator)
{
    enum long numerator = Numerator;
    enum long denominator = Denominator;
}

struct Metre
{
    alias Dimension = LengthDimension;
    alias UnitScale = Scale!(1, 1);
}

struct Kilometre
{
    alias Dimension = LengthDimension;
    alias UnitScale = Scale!(1000, 1);
}

struct Centimetre
{
    alias Dimension = LengthDimension;
    alias UnitScale = Scale!(1, 100);
}

struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

// R14 API-shape probe only. The real exact-ratio conversion kernel is a
// separate gate; keeping this kernel shared prevents API alternatives from
// accidentally benchmarking different conversion semantics.
@safe pure nothrow @nogc
ConversionResult!T probeChecked(T)(T value)
{
    return ConversionResult!T(value, ConversionStatus.exact);
}


struct HalfMetre
{
    alias Dimension = LengthDimension;
    alias UnitScale = Scale!(1, 2);
}

struct TenthMetre
{
    alias Dimension = LengthDimension;
    alias UnitScale = Scale!(1, 10);
}
