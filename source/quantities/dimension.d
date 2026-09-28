module quantities.dimension;

import std.meta : AliasSeq;
import std.traits : fullyQualifiedName;

/// One exponent term in a physical dimension.
///
/// Tag identity is nominal D type identity. Consumers may define their own
/// empty tag structs without registering them in quantities-d.
struct DimensionTerm(Tag, int Exponent)
{
    alias DimensionTag = Tag;
    enum exponent = Exponent;
}

private struct TermList(Terms...)
{
    alias items = AliasSeq!Terms;
    enum length = Terms.length;
}

private template tagKey(Tag)
{
    enum tagKey = fullyQualifiedName!Tag;
}

private template termLess(A, B)
{
    static if (is(A.DimensionTag == B.DimensionTag))
        enum termLess = false;
    else
        enum termLess = tagKey!(A.DimensionTag) < tagKey!(B.DimensionTag);
}

private template InsertCanonical(List, Term)
{
    static if (Term.exponent == 0)
        alias InsertCanonical = List;
    else static if (List.length == 0)
        alias InsertCanonical = TermList!Term;
    else static if (is(List.items[0].DimensionTag == Term.DimensionTag))
    {
        enum exponent = List.items[0].exponent + Term.exponent;

        static if (exponent == 0)
            alias InsertCanonical = TermList!(List.items[1 .. $]);
        else
            alias InsertCanonical = TermList!(
                DimensionTerm!(Term.DimensionTag, exponent),
                List.items[1 .. $]);
    }
    else static if (termLess!(Term, List.items[0]))
        alias InsertCanonical = TermList!(Term, List.items);
    else
    {
        alias tail = InsertCanonical!(
            TermList!(List.items[1 .. $]), Term);
        alias InsertCanonical = TermList!(List.items[0], tail.items);
    }
}

private template Normalize(Terms...)
{
    static if (Terms.length == 0)
        alias Normalize = TermList!();
    else
    {
        alias tail = Normalize!(Terms[1 .. $]);
        alias Normalize = InsertCanonical!(tail, Terms[0]);
    }
}

private struct CanonicalDimension(Terms...)
{
    private alias terms = TermList!Terms;
}

/// Canonical physical dimension.
///
/// Terms are sorted by the fully-qualified name of their nominal tag type,
/// equal tags are merged, and zero exponents disappear before the concrete
/// dimension type is formed.
template Dimension(Terms...)
{
    alias normalized = Normalize!Terms;
    alias Dimension = CanonicalDimension!(normalized.items);
}

/// Convenience constructor for one independent base dimension.
template BaseDimension(Tag)
{
    alias BaseDimension = Dimension!(DimensionTerm!(Tag, 1));
}

/// Multiplicative identity of dimension algebra.
alias Dimensionless = Dimension!();

private template NegateTerms(List)
{
    static if (List.length == 0)
        alias NegateTerms = TermList!();
    else
    {
        alias tail = NegateTerms!(TermList!(List.items[1 .. $]));
        alias NegateTerms = TermList!(
            DimensionTerm!(
                List.items[0].DimensionTag,
                -List.items[0].exponent),
            tail.items);
    }
}

private template ScaleTerms(List, int Power)
{
    static if (List.length == 0)
        alias ScaleTerms = TermList!();
    else
    {
        alias tail = ScaleTerms!(
            TermList!(List.items[1 .. $]), Power);
        alias ScaleTerms = TermList!(
            DimensionTerm!(
                List.items[0].DimensionTag,
                List.items[0].exponent * Power),
            tail.items);
    }
}

/// Product of two physical dimensions.
template MultiplyDimension(A, B)
{
    alias MultiplyDimension = Dimension!(A.terms.items, B.terms.items);
}

/// Quotient of two physical dimensions.
template DivideDimension(A, B)
{
    alias negativeB = NegateTerms!(B.terms);
    alias DivideDimension = Dimension!(A.terms.items, negativeB.items);
}

/// Integral power of a physical dimension.
template PowerDimension(A, int Power)
{
    alias scaled = ScaleTerms!(A.terms, Power);
    alias PowerDimension = Dimension!(scaled.items);
}

@safe unittest
{
    struct LengthTag {}
    struct TimeTag {}
    struct ConsumerAxisTag {}

    alias Length = BaseDimension!LengthTag;
    alias Time = BaseDimension!TimeTag;
    alias ConsumerAxis = BaseDimension!ConsumerAxisTag;

    alias Area = PowerDimension!(Length, 2);
    alias Velocity = DivideDimension!(Length, Time);
    alias Acceleration = DivideDimension!(Velocity, Time);

    static assert(is(Area ==
        Dimension!(DimensionTerm!(LengthTag, 2))));
    static assert(is(Velocity ==
        Dimension!(
            DimensionTerm!(LengthTag, 1),
            DimensionTerm!(TimeTag, -1))));
    static assert(is(Acceleration ==
        Dimension!(
            DimensionTerm!(LengthTag, 1),
            DimensionTerm!(TimeTag, -2))));

    static assert(is(DivideDimension!(Length, Length) == Dimensionless));
    static assert(is(MultiplyDimension!(Length, Dimensionless) == Length));
    static assert(is(PowerDimension!(Length, 0) == Dimensionless));
    static assert(is(PowerDimension!(Length, -1) ==
        Dimension!(DimensionTerm!(LengthTag, -1))));

    static assert(is(
        MultiplyDimension!(Length, Time) ==
        MultiplyDimension!(Time, Length)));

    static assert(is(MultiplyDimension!(Velocity, Time) == Length));
    static assert(is(DivideDimension!(Area, Length) == Length));

    // No central registry is required for consumer-defined base dimensions.
    static assert(is(
        MultiplyDimension!(Length, ConsumerAxis) ==
        MultiplyDimension!(ConsumerAxis, Length)));
}
