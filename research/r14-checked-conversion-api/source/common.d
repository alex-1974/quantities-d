module common;

enum ConversionStatus
{
    exact,
    inexact,
    overflow
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

struct Metre
{
    alias Dimension = LengthDimension;
}

struct Kilometre
{
    alias Dimension = LengthDimension;
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
