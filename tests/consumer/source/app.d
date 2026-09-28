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

    enum arithmeticLhs = int.max.quantity!(Length, Metre);
    enum arithmeticRhs = uint.max.quantity!(Length, Metre);
    enum arithmeticSum = arithmeticLhs + arithmeticRhs;
    static assert(is(typeof(arithmeticSum) == Quantity!(Length, long)));
    static assert(arithmeticSum.canonicalValue
        == cast(long)int.max + cast(long)uint.max);

    enum arithmeticDifference =
        0u.quantity!(Length, Metre)
        - uint.max.quantity!(Length, Metre);
    static assert(is(typeof(arithmeticDifference) == Quantity!(Length, long)));
    static assert(arithmeticDifference.canonicalValue
        == -cast(long)uint.max);

    enum arithmeticProduct =
        uint.max.quantity!(Length, Metre) * uint.max;
    enum arithmeticProductRight =
        uint.max * uint.max.quantity!(Length, Metre);
    static assert(is(typeof(arithmeticProduct) == Quantity!(Length, ulong)));
    static assert(is(typeof(arithmeticProductRight) == Quantity!(Length, ulong)));
    static assert(arithmeticProduct.canonicalValue
        == arithmeticProductRight.canonicalValue);

    enum exactDivision =
        int.min.quantity!(Length, Metre).exactDiv(-1);
    static assert(exactDivision.status == DivisionStatus.exact);
    static assert(exactDivision.hasValue);
    static assert({
        Quantity!(Length, long) value;
        return exactDivision.tryValue(value)
            && value.canonicalValue == -(cast(long)int.min);
    }());

    enum inexactDivision =
        5.quantity!(Length, Metre).exactDiv(2);
    static assert(inexactDivision.status == DivisionStatus.inexact);
    static assert(!inexactDivision.hasValue);

    enum zeroDivision =
        5.quantity!(Length, Metre).exactDiv(0);
    static assert(zeroDivision.status == DivisionStatus.divisionByZero);
    static assert(!zeroDivision.hasValue);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
    static assert(Quantity!(Length, long).sizeof == long.sizeof);
}
