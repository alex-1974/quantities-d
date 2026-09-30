module quantities.quantity;

import quantities.arithmetic_rep :
    AddArithmeticRep,
    MulArithmeticRep,
    QuotientArithmeticRep,
    SubArithmeticRep;
import quantities.arithmetic_traits :
    AddResult,
    ProductCanonicalRescale,
    ProductResultSpec,
    QuotientCanonicalRescale,
    QuotientResultSpec,
    SubResult,
    isScalableValue;
import quantities.traits : isQuantitySpec, isUnit;

struct Quantity(Spec, Rep)
{
    static assert(isQuantitySpec!Spec,
        "Quantity Spec must define Dimension and a valid CanonicalUnit with the same Dimension.");

private:
    Rep canonical_;

    @safe pure nothrow @nogc
    this(Rep canonical)
    {
        canonical_ = canonical;
    }

    @safe pure nothrow @nogc
    package(quantities) static Quantity fromCanonical(Rep canonical)
    {
        return Quantity(canonical);
    }

public:
    @safe pure nothrow @nogc
    Rep canonicalValue() const
    {
        return canonical_;
    }

    @safe pure nothrow @nogc
    auto opBinary(string op, OtherSpec, OtherRep)(
        Quantity!(OtherSpec, OtherRep) rhs) const
        if (op == "+" &&
            !is(AddResult!(Spec, OtherSpec) == void) &&
            !is(AddArithmeticRep!(Rep, OtherRep) == void))
    {
        alias ResultSpec = AddResult!(Spec, OtherSpec);
        alias ResultRep = AddArithmeticRep!(Rep, OtherRep);

        return Quantity!(ResultSpec, ResultRep).fromCanonical(
            cast(ResultRep)canonical_ +
            cast(ResultRep)rhs.canonicalValue);
    }

    @safe pure nothrow @nogc
    auto opBinary(string op, OtherSpec, OtherRep)(
        Quantity!(OtherSpec, OtherRep) rhs) const
        if (op == "-" &&
            !is(SubResult!(Spec, OtherSpec) == void) &&
            !is(SubArithmeticRep!(Rep, OtherRep) == void))
    {
        alias ResultSpec = SubResult!(Spec, OtherSpec);
        alias ResultRep = SubArithmeticRep!(Rep, OtherRep);

        return Quantity!(ResultSpec, ResultRep).fromCanonical(
            cast(ResultRep)canonical_ -
            cast(ResultRep)rhs.canonicalValue);
    }

    @safe pure nothrow @nogc
    auto opBinary(string op, OtherSpec, OtherRep)(
        Quantity!(OtherSpec, OtherRep) rhs) const
        if (op == "*" &&
            !is(ProductResultSpec!(Spec, OtherSpec) == void) &&
            !is(MulArithmeticRep!(Rep, OtherRep) == void) &&
            ProductCanonicalRescale!(
                Spec,
                OtherSpec,
                ProductResultSpec!(Spec, OtherSpec)).numerator == 1 &&
            ProductCanonicalRescale!(
                Spec,
                OtherSpec,
                ProductResultSpec!(Spec, OtherSpec)).denominator == 1)
    {
        alias ResultSpec = ProductResultSpec!(Spec, OtherSpec);
        alias ResultRep = MulArithmeticRep!(Rep, OtherRep);

        return Quantity!(ResultSpec, ResultRep).fromCanonical(
            cast(ResultRep)canonical_ *
            cast(ResultRep)rhs.canonicalValue);
    }

    @safe pure nothrow @nogc
    auto opBinary(string op, OtherSpec, OtherRep)(
        Quantity!(OtherSpec, OtherRep) rhs) const
        if (op == "/" &&
            !is(QuotientResultSpec!(Spec, OtherSpec) == void) &&
            !is(QuotientArithmeticRep!(Rep, OtherRep) == void) &&
            QuotientCanonicalRescale!(
                Spec,
                OtherSpec,
                QuotientResultSpec!(Spec, OtherSpec)).numerator == 1 &&
            QuotientCanonicalRescale!(
                Spec,
                OtherSpec,
                QuotientResultSpec!(Spec, OtherSpec)).denominator == 1)
    {
        alias ResultSpec = QuotientResultSpec!(Spec, OtherSpec);
        alias ResultRep = QuotientArithmeticRep!(Rep, OtherRep);

        return Quantity!(ResultSpec, ResultRep).fromCanonical(
            cast(ResultRep)canonical_ /
            cast(ResultRep)rhs.canonicalValue);
    }

    @safe pure nothrow @nogc
    auto opBinary(string op, Scalar)(Scalar scalar) const
        if (op == "*" &&
            isScalableValue!Spec &&
            !is(MulArithmeticRep!(Rep, Scalar) == void))
    {
        alias ResultRep = MulArithmeticRep!(Rep, Scalar);

        return Quantity!(Spec, ResultRep).fromCanonical(
            cast(ResultRep)canonical_ *
            cast(ResultRep)scalar);
    }

    @safe pure nothrow @nogc
    auto opBinaryRight(string op, Scalar)(Scalar scalar) const
        if (op == "*" &&
            isScalableValue!Spec &&
            !is(MulArithmeticRep!(Scalar, Rep) == void))
    {
        alias ResultRep = MulArithmeticRep!(Scalar, Rep);

        return Quantity!(Spec, ResultRep).fromCanonical(
            cast(ResultRep)scalar *
            cast(ResultRep)canonical_);
    }
}

@safe pure nothrow @nogc
auto quantity(Spec, Unit, Rep)(Rep value)
{
    static assert(isQuantitySpec!Spec,
        "quantity: Spec must define Dimension and a valid CanonicalUnit.");
    static assert(isUnit!Unit,
        "quantity: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "quantity: Spec and Unit must have the same Dimension.");

    static if (is(Unit == Spec.CanonicalUnit))
    {
        return Quantity!(Spec, Rep).fromCanonical(value);
    }
    else
    {
        static assert(false,
            "quantity: non-canonical Unit construction requires checkedQuantity, exactQuantity, or roundedQuantity.");
    }
}

@safe pure nothrow @nogc
auto inUnit(Unit, Spec, Rep)(Quantity!(Spec, Rep) value)
{
    static assert(isUnit!Unit,
        "inUnit: Unit must define Dimension and a valid exact Scale.");
    static assert(is(Spec.Dimension == Unit.Dimension),
        "inUnit: Quantity Spec and Unit must have the same Dimension.");

    static if (is(Unit == Spec.CanonicalUnit))
    {
        return value.canonicalValue;
    }
    else
    {
        static assert(false,
            "inUnit: non-canonical Unit extraction requires checkedIn, exactIn, or roundedIn.");
    }
}


@safe unittest
{
    import quantities.length : Length, Metre;

    enum lhs = int.max.quantity!(Length, Metre);
    enum rhs = uint.max.quantity!(Length, Metre);
    enum sum = lhs + rhs;
    static assert(is(typeof(sum) == Quantity!(Length, long)));
    static assert(sum.canonicalValue
        == cast(long)int.max + cast(long)uint.max);

    enum zero = 0u.quantity!(Length, Metre);
    enum umax = uint.max.quantity!(Length, Metre);
    enum difference = zero - umax;
    static assert(is(typeof(difference) == Quantity!(Length, long)));
    static assert(difference.canonicalValue == -cast(long)uint.max);

    static assert(!__traits(compiles,
        long.max.quantity!(Length, Metre)
            + long.max.quantity!(Length, Metre)));

    // Floating/floating addition and subtraction follow native D promotion.
    enum floatingLhs =
        1.25f.quantity!(Length, Metre);
    enum floatingRhs =
        2.5.quantity!(Length, Metre);
    enum floatingSum =
        floatingLhs + floatingRhs;
    enum floatingDifference =
        floatingRhs - floatingLhs;

    static assert(is(
        typeof(floatingSum)
        == Quantity!(Length, double)));
    static assert(is(
        typeof(floatingDifference)
        == Quantity!(Length, double)));
    static assert(
        floatingSum.canonicalValue
        == 3.75);
    static assert(
        floatingDifference.canonicalValue
        == 1.25);

    // Mixed arithmetic is admitted only when the complete integral Rep domain
    // is exactly representable in the floating ResultRep.
    enum shortFloatingSum =
        (cast(short)32_767).quantity!(Length, Metre)
        + 0.5f.quantity!(Length, Metre);
    static assert(is(
        typeof(shortFloatingSum)
        == Quantity!(Length, float)));
    static assert(
        shortFloatingSum.canonicalValue
        == 32_767.5f);

    enum intDoubleSum =
        int.max.quantity!(Length, Metre)
        + 0.5.quantity!(Length, Metre);
    static assert(is(
        typeof(intDoubleSum)
        == Quantity!(Length, double)));
    static assert(
        intDoubleSum.canonicalValue
        == 2_147_483_647.5);

    enum doubleIntDifference =
        0.5.quantity!(Length, Metre)
        - int.max.quantity!(Length, Metre);
    static assert(is(
        typeof(doubleIntDifference)
        == Quantity!(Length, double)));
    static assert(
        doubleIntDifference.canonicalValue
        == -2_147_483_646.5);

    static assert(!__traits(compiles,
        1.quantity!(Length, Metre)
            + 0.5f.quantity!(Length, Metre)));
    static assert(!__traits(compiles,
        long.max.quantity!(Length, Metre)
            + 0.5.quantity!(Length, Metre)));
    static assert(!__traits(compiles,
        0.5.quantity!(Length, Metre)
            - long.max.quantity!(Length, Metre)));

    struct Radius
    {
        alias Dimension = Length.Dimension;
        alias CanonicalUnit = Metre;
    }

    static assert(!__traits(compiles,
        1.quantity!(Radius, Metre) + 2.quantity!(Radius, Metre)));
    static assert(!__traits(compiles,
        1.quantity!(Length, Metre) + 2.quantity!(Radius, Metre)));

    enum area =
        3.quantity!(Length, Metre)
        * 4.quantity!(Length, Metre);
    static assert(({
        import quantities.area : Area;
        static assert(is(typeof(area) == Quantity!(Area, long)));
        return area.canonicalValue == 12;
    }()));

    // Floating Quantity products reuse the existing semantic ResultSpec
    // relation when canonical rescaling is exactly 1/1.
    enum floatingArea =
        1.5f.quantity!(Length, Metre)
        * 2.0.quantity!(Length, Metre);
    static assert(({
        import quantities.area : Area;
        static assert(is(
            typeof(floatingArea)
            == Quantity!(Area, double)));
        return floatingArea.canonicalValue == 3.0;
    }()));

    enum mixedArea =
        int.max.quantity!(Length, Metre)
        * 0.5.quantity!(Length, Metre);
    static assert(({
        import quantities.area : Area;
        static assert(is(
            typeof(mixedArea)
            == Quantity!(Area, double)));
        return mixedArea.canonicalValue
            == 1_073_741_823.5;
    }()));

    static assert(!__traits(compiles,
        1.quantity!(Length, Metre)
            * 0.5f.quantity!(Length, Metre)));
    static assert(!__traits(compiles,
        long.max.quantity!(Length, Metre)
            * 0.5.quantity!(Length, Metre)));

    // Floating direct quotient requires an explicit semantic quotient relation
    // and an exact identity canonical rescale.
    static struct RatioSpec
    {
        import quantities.dimension : Dimensionless;
        import quantities.ratio : ExactRatio;
        import quantities.unit : DerivedUnit;

        alias Dimension = Dimensionless;
        alias CanonicalUnit = DerivedUnit!(
            Dimensionless,
            ExactRatio!(1, 1));
    }

    static struct QuotientLength
    {
        alias Dimension = Length.Dimension;
        alias CanonicalUnit = Metre;

        template QuotientWith(Rhs)
        {
            alias QuotientWith = RatioSpec;
        }
    }

    enum floatingQuotient =
        3.0.quantity!(QuotientLength, Metre)
        / 1.5f.quantity!(QuotientLength, Metre);
    static assert(is(
        typeof(floatingQuotient)
        == Quantity!(RatioSpec, double)));
    static assert(
        floatingQuotient.canonicalValue
        == 2.0);

    enum mixedQuotient =
        int.max.quantity!(QuotientLength, Metre)
        / 0.5.quantity!(QuotientLength, Metre);
    static assert(is(
        typeof(mixedQuotient)
        == Quantity!(RatioSpec, double)));
    static assert(
        mixedQuotient.canonicalValue
        == 4_294_967_294.0);

    static assert(!__traits(compiles,
        1.quantity!(QuotientLength, Metre)
            / 0.5f.quantity!(QuotientLength, Metre)));
    static assert(!__traits(compiles,
        long.max.quantity!(QuotientLength, Metre)
            / 0.5.quantity!(QuotientLength, Metre)));
    static assert(!__traits(compiles,
        6.quantity!(QuotientLength, Metre)
            / 3.quantity!(QuotientLength, Metre)));

    enum product =
        uint.max.quantity!(Length, Metre) * uint.max;
    static assert(is(typeof(product) == Quantity!(Length, ulong)));
    static assert(product.canonicalValue
        == cast(ulong)uint.max * cast(ulong)uint.max);

    enum productRight =
        uint.max * uint.max.quantity!(Length, Metre);
    static assert(is(typeof(productRight) == Quantity!(Length, ulong)));
    static assert(productRight.canonicalValue == product.canonicalValue);

    // Floating scalar multiplication follows native D promotion after the
    // full-domain operand-admission gate succeeds.
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
    static assert(
        floatingScalarProduct.canonicalValue
        == 3.0);
    static assert(
        floatingScalarProductRight.canonicalValue
        == 3.0);

    enum intDoubleProduct =
        int.max.quantity!(Length, Metre) * 0.5;
    enum doubleIntProduct =
        0.5 * int.max.quantity!(Length, Metre);
    static assert(is(
        typeof(intDoubleProduct)
        == Quantity!(Length, double)));
    static assert(is(
        typeof(doubleIntProduct)
        == Quantity!(Length, double)));
    static assert(
        intDoubleProduct.canonicalValue
        == 1_073_741_823.5);
    static assert(
        doubleIntProduct.canonicalValue
        == 1_073_741_823.5);

    enum shortFloatProduct =
        (cast(short)32_767).quantity!(Length, Metre) * 0.5f;
    static assert(is(
        typeof(shortFloatProduct)
        == Quantity!(Length, float)));

    static assert(!__traits(compiles,
        1.quantity!(Length, Metre) * 0.5f));
    static assert(!__traits(compiles,
        long.max.quantity!(Length, Metre) * 0.5));
    static assert(!__traits(compiles,
        0.5 * long.max.quantity!(Length, Metre)));

    static assert(!__traits(compiles,
        ulong.max.quantity!(Length, Metre) * ulong.max));

    static assert(!__traits(compiles,
        2.quantity!(Radius, Metre) * 3));
    static assert(!__traits(compiles,
        3 * 2.quantity!(Radius, Metre)));
}
