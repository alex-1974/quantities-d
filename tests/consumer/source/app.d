module app;

import quantities;

void main()
{
    enum canonical = 1.25.quantity!(Length, Metre);
    static assert(canonical.canonicalValue == 1.25);
    static assert(canonical.inUnit!Metre == 1.25);

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

    enum internationalFeet =
        1250L.exactQuantity!(Length, InternationalFoot);
    static assert(internationalFeet.hasValue);
    static assert({
        Quantity!(Length, long) value;
        return internationalFeet.tryValue(value)
            && value.canonicalValue == 381L;
    }());

    enum surveyFeet =
        3937L.exactQuantity!(Length, USSurveyFoot);
    static assert(surveyFeet.hasValue);
    static assert({
        Quantity!(Length, long) value;
        return surveyFeet.tryValue(value)
            && value.canonicalValue == 1200L;
    }());

    enum inexactFoot =
        1L.exactQuantity!(Length, InternationalFoot);
    static assert(!inexactFoot.hasValue);
    static assert({
        ExactFailure failure;
        return inexactFoot.tryFailure(failure)
            && failure == ExactFailure.inexact;
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

    const internationalDouble =
        1.0.checkedQuantity!(Length, InternationalFoot);
    assert(internationalDouble.hasValue);

    const surveyDouble =
        1.0.checkedQuantity!(Length, USSurveyFoot);
    assert(surveyDouble.hasValue);

    Quantity!(Length, double) internationalValue;
    Quantity!(Length, double) surveyValue;
    assert(internationalDouble.tryValue(internationalValue));
    assert(surveyDouble.tryValue(surveyValue));
    assert(internationalValue.canonicalValue
        != surveyValue.canonicalValue);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
    static assert(Quantity!(Length, long).sizeof == long.sizeof);
}
