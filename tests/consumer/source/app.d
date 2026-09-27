module app;

import quantities;

struct LengthDimension {}

struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1);
}

struct Kilometre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1000, 1);
}

struct Centimetre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 100);
}

struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

void main()
{
    enum ctfe = 1.25.quantity!(Length, Metre);
    static assert(ctfe.canonicalValue == 1.25);
    static assert(ctfe.inUnit!Metre == 1.25);

    auto runtime = 2.5.quantity!(Length, Metre);
    assert(runtime.canonicalValue == 2.5);

    auto integral = 7L.quantity!(Length, Metre);
    assert(integral.canonicalValue == 7L);

    enum exactKilometres = 2L.exactQuantity!(Length, Kilometre);
    static assert(exactKilometres.hasValue);
    static assert({
        Quantity!(Length, long) value;
        return exactKilometres.tryValue(value)
            && value.canonicalValue == 2000L;
    }());

    enum inexactCentimetres = 150L.exactQuantity!(Length, Centimetre);
    static assert(!inexactCentimetres.hasValue);
    static assert({
        ExactFailure failure;
        return inexactCentimetres.tryFailure(failure)
            && failure == ExactFailure.inexact;
    }());

    enum roundedCentimetres = 150L.roundedQuantity!(
        Length, Centimetre, RoundingMode.nearestTiesAway);
    static assert(roundedCentimetres.status == ConversionStatus.inexact);
    static assert({
        Quantity!(Length, long) value;
        return roundedCentimetres.tryValue(value)
            && value.canonicalValue == 2L;
    }());

    enum extracted = {
        Quantity!(Length, long) value;
        assert(exactKilometres.tryValue(value));
        return value.exactIn!Kilometre;
    }();
    static assert(extracted.hasValue);
    static assert({
        long value;
        return extracted.tryValue(value) && value == 2L;
    }());

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
}
