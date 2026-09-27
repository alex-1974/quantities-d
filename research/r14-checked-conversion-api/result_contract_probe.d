// R14 design probe: result contracts only.
// This file is research evidence, not production API.
//
// Goal:
// - checked integral conversion may be inexact without producing a target value;
// - rounded integral and checked floating conversion may be inexact with a value;
// - failed/overflow/non-finite results expose no value;
// - invalid state combinations are not publicly constructible.

module result_contract_probe;

enum ConversionStatus
{
    exact,
    inexact,
    overflow,
    nonFinite
}

struct ConversionResult(T)
{
private:
    bool hasValue_;
    T value_;
    ConversionStatus status_;

    @safe pure nothrow @nogc
    this(bool hasValue, T value, ConversionStatus status)
    {
        hasValue_ = hasValue;
        value_ = value;
        status_ = status;
    }

public:
    @safe pure nothrow @nogc
    static ConversionResult withValue(T value, ConversionStatus status)
    {
        // A produced value can be exact or inexact, but never represent
        // overflow/non-finite failure.
        assert(status == ConversionStatus.exact
            || status == ConversionStatus.inexact);
        return ConversionResult(true, value, status);
    }

    @safe pure nothrow @nogc
    static ConversionResult withoutValue(ConversionStatus status)
    {
        // No-value is meaningful only when exact conversion did not produce T.
        assert(status != ConversionStatus.exact);
        return ConversionResult(false, T.init, status);
    }

    @safe pure nothrow @nogc
    bool hasValue() const
    {
        return hasValue_;
    }

    @safe pure nothrow @nogc
    ConversionStatus status() const
    {
        return status_;
    }

    // Probe deliberately does not add value(): an assert-guarded accessor
    // would recreate the ExactResult release-build problem. Safe access is
    // tested through tryValue instead.
    @safe pure nothrow @nogc
    bool tryValue(out T value) const
    {
        if (!hasValue_)
            return false;

        value = value_;
        return true;
    }
}

@safe pure nothrow @nogc
bool valueEquals(T)(ConversionResult!T result, T expected)
{
    T value;
    return result.tryValue(value) && value == expected;
}

@safe unittest
{
    // checked integral: exact -> value
    enum checkedIntegralExact =
        ConversionResult!long.withValue(2, ConversionStatus.exact);
    static assert(checkedIntegralExact.hasValue);
    static assert(checkedIntegralExact.status == ConversionStatus.exact);
    static assert(valueEquals(checkedIntegralExact, 2));

    // checked integral: inexact -> deliberately no invented/sentinel value
    enum checkedIntegralInexact =
        ConversionResult!long.withoutValue(ConversionStatus.inexact);
    static assert(!checkedIntegralInexact.hasValue);
    static assert(checkedIntegralInexact.status == ConversionStatus.inexact);

    // rounded integral: inexact -> caller selected a policy, so value exists
    enum roundedIntegralInexact =
        ConversionResult!long.withValue(2, ConversionStatus.inexact);
    static assert(roundedIntegralInexact.hasValue);
    static assert(roundedIntegralInexact.status == ConversionStatus.inexact);
    static assert(valueEquals(roundedIntegralInexact, 2));

    // checked floating: IEEE target quantization inherently produces a value
    // even when exact rational scaling is not exactly representable.
    enum checkedFloatingInexact =
        ConversionResult!double.withValue(0.1, ConversionStatus.inexact);
    static assert(checkedFloatingInexact.hasValue);
    static assert(checkedFloatingInexact.status == ConversionStatus.inexact);
    static assert(valueEquals(checkedFloatingInexact, 0.1));

    enum overflow =
        ConversionResult!long.withoutValue(ConversionStatus.overflow);
    static assert(!overflow.hasValue);
    static assert(overflow.status == ConversionStatus.overflow);

    enum nonFinite =
        ConversionResult!double.withoutValue(ConversionStatus.nonFinite);
    static assert(!nonFinite.hasValue);
    static assert(nonFinite.status == ConversionStatus.nonFinite);

    // Safe no-value observation remains defined in release builds and CTFE.
    static assert({
        long unavailable;
        return !checkedIntegralInexact.tryValue(unavailable);
    }());
}


enum ExactFailure
{
    inexact,
    overflow,
    nonFinite
}

struct ExactResult(T)
{
private:
    bool hasValue_;
    T value_;
    ExactFailure failure_;

public:
    @safe pure nothrow @nogc
    static ExactResult success(T value)
    {
        ExactResult result;
        result.hasValue_ = true;
        result.value_ = value;
        return result;
    }

    @safe pure nothrow @nogc
    static ExactResult failed(ExactFailure failure)
    {
        ExactResult result;
        result.failure_ = failure;
        return result;
    }

    @safe pure nothrow @nogc
    bool hasValue() const
    {
        return hasValue_;
    }

    // Safe in debug and release builds: no precondition is enforced only
    // by assert. The caller can observe success/failure explicitly.
    @safe pure nothrow @nogc
    bool tryValue(out T value) const
    {
        if (!hasValue_)
            return false;

        value = value_;
        return true;
    }

    @safe pure nothrow @nogc
    bool tryFailure(out ExactFailure failure) const
    {
        if (hasValue_)
            return false;

        failure = failure_;
        return true;
    }
}

@safe unittest
{
    enum exactSuccess = ExactResult!long.success(42);
    static assert(exactSuccess.hasValue);
    static assert({
        long value;
        return exactSuccess.tryValue(value) && value == 42;
    }());
    static assert({
        ExactFailure failure;
        return !exactSuccess.tryFailure(failure);
    }());

    enum exactFailure = ExactResult!long.failed(ExactFailure.inexact);
    static assert(!exactFailure.hasValue);
    static assert({
        long value;
        return !exactFailure.tryValue(value);
    }());
    static assert({
        ExactFailure failure;
        return exactFailure.tryFailure(failure)
            && failure == ExactFailure.inexact;
    }());
}
