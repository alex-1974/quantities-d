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

    // Length is a generic linear magnitude: same-Spec addition/subtraction
    // and dimensionless scalar scaling preserve its semantic meaning.
    enum closedAdditiveValue = true;
    enum scalableValue = true;
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

static assert(({
    import quantities.arithmetic_traits :
        AddResult,
        SubResult,
        hasClosedAdditiveValue,
        isScalableValue;

    static assert(hasClosedAdditiveValue!Length);
    static assert(isScalableValue!Length);
    static assert(is(AddResult!(Length, Length) == Length));
    static assert(is(SubResult!(Length, Length) == Length));
    return true;
}()));
static assert(is(Metre.Scale == ExactRatio!(1, 1)));
static assert(is(Kilometre.Scale == ExactRatio!(1000, 1)));
static assert(is(InternationalFoot.Scale == ExactRatio!(381, 1250)));
static assert(is(USSurveyFoot.Scale == ExactRatio!(1200, 3937)));


@safe unittest
{
    import quantities.conversion :
        ConversionStatus,
        ExactFailure,
        RoundingMode,
        checkedQuantity,
        exactIn,
        exactQuantity,
        roundedQuantity;
    import quantities.quantity : Quantity, quantity;

    // Exact integral conversions to the canonical metre.
    enum twoKm = 2L.exactQuantity!(Length, Kilometre);
    static assert(twoKm.hasValue);
    static assert(({
        Quantity!(Length, long) value;
        return twoKm.tryValue(value) && value.canonicalValue == 2000;
    }()));

    enum backToKm = 2000L.quantity!(Length, Metre).exactIn!Kilometre;
    static assert(backToKm.hasValue);
    static assert(({
        long value;
        return backToKm.tryValue(value) && value == 2;
    }()));

    // Exact rational foot definitions must remain distinguishable.
    static assert(InternationalFoot.Scale.numerator == 381);
    static assert(InternationalFoot.Scale.denominator == 1250);
    static assert(USSurveyFoot.Scale.numerator == 1200);
    static assert(USSurveyFoot.Scale.denominator == 3937);
    static assert(!is(InternationalFoot.Scale == USSurveyFoot.Scale));

    // 1250 international feet are exactly 381 canonical metres.
    enum internationalExact =
        1250L.exactQuantity!(Length, InternationalFoot);
    static assert(internationalExact.hasValue);
    static assert(({
        Quantity!(Length, long) value;
        return internationalExact.tryValue(value)
            && value.canonicalValue == 381;
    }()));

    // 3937 US survey feet are exactly 1200 canonical metres.
    enum surveyExact =
        3937L.exactQuantity!(Length, USSurveyFoot);
    static assert(surveyExact.hasValue);
    static assert(({
        Quantity!(Length, long) value;
        return surveyExact.tryValue(value)
            && value.canonicalValue == 1200;
    }()));

    // One foot cannot be represented exactly by an integral canonical metre.
    enum internationalChecked =
        1L.checkedQuantity!(Length, InternationalFoot);
    static assert(internationalChecked.status == ConversionStatus.inexact);
    static assert(!internationalChecked.hasValue);

    enum surveyChecked =
        1L.checkedQuantity!(Length, USSurveyFoot);
    static assert(surveyChecked.status == ConversionStatus.inexact);
    static assert(!surveyChecked.hasValue);

    // Negative rounding remains sign-correct for the real M2 units.
    enum negativeInternationalFloor =
        (-1L).roundedQuantity!(
            Length, InternationalFoot, RoundingMode.floor);
    static assert(negativeInternationalFloor.status
        == ConversionStatus.inexact);
    static assert(({
        Quantity!(Length, long) value;
        return negativeInternationalFloor.tryValue(value)
            && value.canonicalValue == -1;
    }()));

    enum negativeInternationalTowardZero =
        (-1L).roundedQuantity!(
            Length, InternationalFoot, RoundingMode.towardZero);
    static assert(negativeInternationalTowardZero.status
        == ConversionStatus.inexact);
    static assert(({
        Quantity!(Length, long) value;
        return negativeInternationalTowardZero.tryValue(value)
            && value.canonicalValue == 0;
    }()));

    // Runtime binary64 probes exercise the exact rational unit scales without
    // pretending arbitrary non-canonical floating conversions are CTFE.
    const internationalDouble =
        1.0.checkedQuantity!(Length, InternationalFoot);
    assert(internationalDouble.hasValue);
    assert(internationalDouble.status == ConversionStatus.inexact);
    Quantity!(Length, double) internationalValue;
    assert(internationalDouble.tryValue(internationalValue));
    assert(internationalValue.canonicalValue == 0.3048);

    const surveyDouble =
        1.0.checkedQuantity!(Length, USSurveyFoot);
    assert(surveyDouble.hasValue);
    assert(surveyDouble.status == ConversionStatus.inexact);
    Quantity!(Length, double) surveyValue;
    assert(surveyDouble.tryValue(surveyValue));

    // The two legally distinct foot definitions must not collapse to the same
    // represented canonical value.
    assert(surveyValue.canonicalValue
        != internationalValue.canonicalValue);

    // ExactResult must retain the normal M1 failure vocabulary for a real M2
    // inexact conversion.
    enum oneInternationalFoot =
        1L.exactQuantity!(Length, InternationalFoot);
    static assert(!oneInternationalFoot.hasValue);
    static assert(({
        ExactFailure failure;
        return oneInternationalFoot.tryFailure(failure)
            && failure == ExactFailure.inexact;
    }()));
}
