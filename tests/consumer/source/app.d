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

    enum checkedLongAdd =
        long.max.quantity!(Length, Metre)
        .checkedAdd((-1L).quantity!(Length, Metre));
    static assert(checkedLongAdd.hasValue);
    static assert({
        Quantity!(Length, long) value;
        return checkedLongAdd.tryValue(value)
            && value.canonicalValue == long.max - 1;
    }());

    enum checkedLongOverflow =
        long.max.quantity!(Length, Metre)
        .checkedAdd(1L.quantity!(Length, Metre));
    static assert(!checkedLongOverflow.hasValue);
    static assert({
        CheckedAddFailure failure;
        return checkedLongOverflow.tryFailure(failure)
            && failure == CheckedAddFailure.overflow;
    }());

    enum checkedLongMin =
        long.min.quantity!(Length, Metre)
        .checkedAdd(1L.quantity!(Length, Metre));
    static assert(checkedLongMin.hasValue);

    enum checkedUlongOverflow =
        ulong.max.quantity!(Length, Metre)
        .checkedAdd(1UL.quantity!(Length, Metre));
    static assert(!checkedUlongOverflow.hasValue);

    CheckedAddResult!(Quantity!(Length, long)) defaultCheckedAdd;
    assert(!defaultCheckedAdd.hasValue);
    CheckedAddFailure defaultFailure;
    assert(defaultCheckedAdd.tryFailure(defaultFailure));
    assert(defaultFailure == CheckedAddFailure.overflow);

    enum checkedLongSub =
        long.min.quantity!(Length, Metre)
        .checkedSub((-1L).quantity!(Length, Metre));
    static assert(checkedLongSub.hasValue);
    static assert({
        Quantity!(Length, long) value;
        return checkedLongSub.tryValue(value)
            && value.canonicalValue == long.min + 1;
    }());

    enum checkedLongSubOverflow =
        long.min.quantity!(Length, Metre)
        .checkedSub(1L.quantity!(Length, Metre));
    static assert(!checkedLongSubOverflow.hasValue);
    static assert({
        CheckedSubFailure failure;
        return checkedLongSubOverflow.tryFailure(failure)
            && failure == CheckedSubFailure.overflow;
    }());

    enum checkedLongSubUpperOverflow =
        long.max.quantity!(Length, Metre)
        .checkedSub((-1L).quantity!(Length, Metre));
    static assert(!checkedLongSubUpperOverflow.hasValue);

    enum checkedUlongSub =
        ulong.max.quantity!(Length, Metre)
        .checkedSub(1UL.quantity!(Length, Metre));
    static assert(checkedUlongSub.hasValue);

    enum checkedUlongSubOverflow =
        0UL.quantity!(Length, Metre)
        .checkedSub(1UL.quantity!(Length, Metre));
    static assert(!checkedUlongSubOverflow.hasValue);

    CheckedSubResult!(Quantity!(Length, long)) defaultCheckedSub;
    assert(!defaultCheckedSub.hasValue);
    CheckedSubFailure defaultSubFailure;
    assert(defaultCheckedSub.tryFailure(defaultSubFailure));
    assert(defaultSubFailure == CheckedSubFailure.overflow);

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

    enum floatingScalarProduct =
        1.5f.quantity!(Length, Metre) * 2.0;
    enum floatingScalarProductRight =
        2.0 * 1.5f.quantity!(Length, Metre);
    static assert(is(
        typeof(floatingScalarProduct)
        == Quantity!(Length, double)));
    static assert(is(
        typeof(floatingScalarProductRight)
        == Quantity!(Length, double)));
    static assert(floatingScalarProduct.canonicalValue == 3.0);
    static assert(floatingScalarProductRight.canonicalValue == 3.0);

    enum mixedScalarProduct =
        int.max.quantity!(Length, Metre) * 0.5;
    static assert(is(
        typeof(mixedScalarProduct)
        == Quantity!(Length, double)));
    static assert(
        mixedScalarProduct.canonicalValue
        == 1_073_741_823.5);

    enum floatingQuantityProduct =
        1.5f.quantity!(Length, Metre)
        * 2.0.quantity!(Length, Metre);
    static assert(is(
        typeof(floatingQuantityProduct)
        == Quantity!(Area, double)));
    static assert(
        floatingQuantityProduct.canonicalValue
        == 3.0);

    enum mixedQuantityProduct =
        int.max.quantity!(Length, Metre)
        * 0.5.quantity!(Length, Metre);
    static assert(is(
        typeof(mixedQuantityProduct)
        == Quantity!(Area, double)));
    static assert(
        mixedQuantityProduct.canonicalValue
        == 1_073_741_823.5);

    alias ConsumerScaledAreaUnit = DerivedUnit!(
        AreaDimension,
        ExactRatio!(3, 2));

    struct ConsumerScaledArea
    {
        alias Dimension = AreaDimension;
        alias CanonicalUnit = ConsumerScaledAreaUnit;
    }

    struct ScaledProductLength
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;

        template ProductWith(Rhs)
        {
            alias ProductWith = ConsumerScaledArea;
        }
    }

    auto rescaledConsumerProduct =
        1.5.quantity!(ScaledProductLength, Metre)
        * 2.0.quantity!(ScaledProductLength, Metre);
    assert(is(
        typeof(rescaledConsumerProduct)
        == Quantity!(ConsumerScaledArea, double)));
    // Mathematical product is 3 and canonical rescale is 2/3.
    assert(rescaledConsumerProduct.canonicalValue == 2.0);

    auto rescaledFloatConsumerProduct =
        1.5f.quantity!(ScaledProductLength, Metre)
        * 2.0f.quantity!(ScaledProductLength, Metre);
    assert(is(
        typeof(rescaledFloatConsumerProduct)
        == Quantity!(ConsumerScaledArea, float)));
    assert(rescaledFloatConsumerProduct.canonicalValue == 2.0f);

    enum scalarDivision =
        3.0.quantity!(Length, Metre) / 2.0;
    static assert(is(
        typeof(scalarDivision)
        == Quantity!(Length, double)));
    static assert(scalarDivision.canonicalValue == 1.5);

    enum mixedScalarDivision =
        int.max.quantity!(Length, Metre) / 0.5;
    static assert(is(
        typeof(mixedScalarDivision)
        == Quantity!(Length, double)));
    static assert(
        mixedScalarDivision.canonicalValue
        == 4_294_967_294.0);

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

    enum checkedProduct =
        long(3).quantity!(Length, Metre)
        .checkedMul(long(4).quantity!(Length, Metre));
    static assert(checkedProduct.hasValue);
    static assert({
        Quantity!(Area, long) value;
        return checkedProduct.tryValue(value)
            && value.canonicalValue == 12;
    }());

    enum checkedProductOverflow =
        long.max.quantity!(Length, Metre)
        .checkedMul(long(2).quantity!(Length, Metre));
    static assert(!checkedProductOverflow.hasValue);
    static assert({
        CheckedMulFailure failure;
        return checkedProductOverflow.tryFailure(failure)
            && failure == CheckedMulFailure.overflow;
    }());

    enum checkedProductMin =
        long.min.quantity!(Length, Metre)
        .checkedMul(long(1).quantity!(Length, Metre));
    static assert(checkedProductMin.hasValue);
    static assert({
        Quantity!(Area, long) value;
        return checkedProductMin.tryValue(value)
            && value.canonicalValue == long.min;
    }());

    enum checkedUnsignedProductOverflow =
        ulong.max.quantity!(Length, Metre)
        .checkedMul(2UL.quantity!(Length, Metre));
    static assert(!checkedUnsignedProductOverflow.hasValue);

    CheckedMulResult!(Quantity!(Area, long)) defaultCheckedMul;
    assert(!defaultCheckedMul.hasValue);
    CheckedMulFailure defaultMulFailure;
    assert(defaultCheckedMul.tryFailure(defaultMulFailure));
    assert(defaultMulFailure == CheckedMulFailure.overflow);

    alias CheckedSquareKilometre = DerivedUnit!(
        AreaDimension,
        ExactRatio!(1_000_000, 1));

    struct CheckedAreaKm2
    {
        alias Dimension = AreaDimension;
        alias CanonicalUnit = CheckedSquareKilometre;
    }

    struct CheckedLengthToKm2
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;

        template ProductWith(Rhs)
        {
            alias ProductWith = CheckedAreaKm2;
        }
    }

    // The raw product overflows long, but cancellation by the canonical
    // denominator proves the final mathematical result fits.
    enum checkedRescaledProduct =
        1_000_000_000_000L.quantity!(CheckedLengthToKm2, Metre)
        .checkedMul(
            1_000_000_000_000L.quantity!(CheckedLengthToKm2, Metre));
    static assert(checkedRescaledProduct.hasValue);
    static assert({
        Quantity!(CheckedAreaKm2, long) value;
        return checkedRescaledProduct.tryValue(value)
            && value.canonicalValue == 1_000_000_000_000_000_000L;
    }());

    enum checkedInexactProduct =
        1L.quantity!(CheckedLengthToKm2, Metre)
        .checkedMul(1L.quantity!(CheckedLengthToKm2, Metre));
    static assert(!checkedInexactProduct.hasValue);
    static assert({
        CheckedMulFailure failure;
        return checkedInexactProduct.tryFailure(failure)
            && failure == CheckedMulFailure.inexact;
    }());

    // Root-level semantic product resolvers are part of the external API.
    static assert(is(ProductResultSpec!(Length, Length) == Area));

    struct ForeignLeft
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;
    }

    struct ForeignRight
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;
    }

    struct ConsumerRelations
    {
        template Product(Lhs, Rhs)
        {
            static if (is(Lhs == ForeignLeft) && is(Rhs == ForeignRight))
                alias Product = Area;
            else
                alias Product = void;
        }
    }

    static assert(is(
        ExternalProductResultSpec!(
            ConsumerRelations,
            ForeignLeft,
            ForeignRight) == Area));


    alias ConsumerUnitless = DerivedUnit!(
        Dimensionless,
        ExactRatio!(1, 1));

    struct ConsumerRatio
    {
        alias Dimension = Dimensionless;
        alias CanonicalUnit = ConsumerUnitless;
    }

    struct QuotientLeft
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;

        template QuotientWith(Rhs)
        {
            static if (is(Rhs == QuotientRight))
                alias QuotientWith = ConsumerRatio;
            else
                alias QuotientWith = void;
        }
    }

    struct QuotientRight
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;
    }

    static assert(is(
        QuotientResultSpec!(QuotientLeft, QuotientRight) ==
        ConsumerRatio));

    enum consumerQuotient =
        6.quantity!(QuotientLeft, Metre)
        .exactDiv(3.quantity!(QuotientRight, Metre));
    static assert(consumerQuotient.status == DivisionStatus.exact);
    static assert({
        Quantity!(ConsumerRatio, long) value;
        return consumerQuotient.tryValue(value)
            && value.canonicalValue == 2;
    }());

    enum floatingConsumerQuotient =
        6.0.quantity!(QuotientLeft, Metre)
        / 4.0f.quantity!(QuotientRight, Metre);
    static assert(is(
        typeof(floatingConsumerQuotient)
        == Quantity!(ConsumerRatio, double)));
    static assert(
        floatingConsumerQuotient.canonicalValue
        == 1.5);

    enum mixedConsumerQuotient =
        int.max.quantity!(QuotientLeft, Metre)
        / 0.5.quantity!(QuotientRight, Metre);
    static assert(is(
        typeof(mixedConsumerQuotient)
        == Quantity!(ConsumerRatio, double)));
    static assert(
        mixedConsumerQuotient.canonicalValue
        == 4_294_967_294.0);

    alias ConsumerScaledUnitless = DerivedUnit!(
        Dimensionless,
        ExactRatio!(3, 2));

    struct ConsumerScaledRatio
    {
        alias Dimension = Dimensionless;
        alias CanonicalUnit = ConsumerScaledUnitless;
    }

    struct ScaledQuotientLeft
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;

        template QuotientWith(Rhs)
        {
            static if (is(Rhs == ScaledQuotientRight))
                alias QuotientWith = ConsumerScaledRatio;
            else
                alias QuotientWith = void;
        }
    }

    struct ScaledQuotientRight
    {
        alias Dimension = LengthDimension;
        alias CanonicalUnit = Metre;
    }

    auto rescaledConsumerQuotient =
        3.0.quantity!(ScaledQuotientLeft, Metre)
        / 2.0.quantity!(ScaledQuotientRight, Metre);
    assert(is(
        typeof(rescaledConsumerQuotient)
        == Quantity!(ConsumerScaledRatio, double)));
    // Mathematical quotient is 3/2 and canonical rescale is 2/3.
    assert(rescaledConsumerQuotient.canonicalValue == 1.0);

    auto rescaledFloatConsumerQuotient =
        3.0f.quantity!(ScaledQuotientLeft, Metre)
        / 2.0f.quantity!(ScaledQuotientRight, Metre);
    assert(is(
        typeof(rescaledFloatConsumerQuotient)
        == Quantity!(ConsumerScaledRatio, float)));
    assert(rescaledFloatConsumerQuotient.canonicalValue == 1.0f);

    struct QuotientRelations
    {
        template Quotient(Lhs, Rhs)
        {
            static if (is(Lhs == ForeignLeft) && is(Rhs == ForeignRight))
                alias Quotient = ConsumerRatio;
            else
                alias Quotient = void;
        }
    }

    static assert(is(
        ExternalQuotientResultSpec!(
            QuotientRelations,
            ForeignLeft,
            ForeignRight) == ConsumerRatio));

    enum externalConsumerQuotient =
        8.quantity!(ForeignLeft, Metre)
        .exactDiv!QuotientRelations(
            4.quantity!(ForeignRight, Metre));
    static assert(externalConsumerQuotient.status == DivisionStatus.exact);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
    static assert(Quantity!(Length, long).sizeof == long.sizeof);
}
