module exact_result_probe;

import checked_kernel : convertIntegral;
import common : ConversionStatus;
import exact_result : ExactFailure;

struct ExactResult(T)
{
    bool hasValue;
    T value;
    ExactFailure failure;
}

@safe pure nothrow @nogc
ExactResult!long exactIntegral(long value, long numerator, long denominator)
{
    const checked = convertIntegral(value, numerator, denominator);

    final switch (checked.status)
    {
        case ConversionStatus.exact:
            return ExactResult!long(true, checked.value, ExactFailure.inexact);
        case ConversionStatus.inexact:
            return ExactResult!long(false, 0, ExactFailure.inexact);
        case ConversionStatus.overflow:
            return ExactResult!long(false, 0, ExactFailure.overflow);
        case ConversionStatus.nonFinite:
            return ExactResult!long(false, 0, ExactFailure.nonFinite);
    }
}

@safe unittest
{
    enum exact = exactIntegral(2, 1000, 1);
    static assert(exact.hasValue);
    static assert(exact.value == 2000);

    enum inexact = exactIntegral(1, 1, 2);
    static assert(!inexact.hasValue);
    static assert(inexact.failure == ExactFailure.inexact);

    enum overflow = exactIntegral(long.max, 2, 1);
    static assert(!overflow.hasValue);
    static assert(overflow.failure == ExactFailure.overflow);
}
