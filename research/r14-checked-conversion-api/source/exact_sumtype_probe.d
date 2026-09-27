module exact_sumtype_probe;

enum ExactFailure
{
    inexact,
    overflow
}

enum ExactState : ubyte
{
    value,
    failure
}

struct ExactResult(T)
{
private:
    ExactState state_;
    T value_;
    ExactFailure failure_;

public:
    @safe pure nothrow @nogc
    static ExactResult success(T value)
    {
        ExactResult result;
        result.state_ = ExactState.value;
        result.value_ = value;
        return result;
    }

    @safe pure nothrow @nogc
    static ExactResult failed(ExactFailure failure)
    {
        ExactResult result;
        result.state_ = ExactState.failure;
        result.failure_ = failure;
        return result;
    }

    @safe pure nothrow @nogc
    bool hasValue() const
    {
        return state_ == ExactState.value;
    }

    @safe pure nothrow @nogc
    T value() const
    {
        assert(hasValue);
        return value_;
    }

    @safe pure nothrow @nogc
    ExactFailure failure() const
    {
        assert(!hasValue);
        return failure_;
    }
}

@safe unittest
{
    enum ok = ExactResult!long.success(42);
    static assert(ok.hasValue);
    static assert(ok.value == 42);

    enum bad = ExactResult!long.failed(ExactFailure.inexact);
    static assert(!bad.hasValue);
    static assert(bad.failure == ExactFailure.inexact);

    static assert(ExactResult!long.sizeof >= long.sizeof);
}
