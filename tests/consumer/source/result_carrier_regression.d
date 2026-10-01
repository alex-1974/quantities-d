module result_carrier_regression;
import quantities.conversion;
import quantities.quantity : Quantity;
import quantities.length : Length, Metre, Kilometre, InternationalFoot;

// External construction must not bypass the invariant-owning carrier boundary.
static assert(!__traits(compiles, ConversionResult!long(true,123,ConversionStatus.overflow)));
static assert(!__traits(compiles, { ConversionResult!long r={true,123,ConversionStatus.overflow}; }));
static assert(!__traits(compiles, { ConversionResult!long r={1,123}; }));
static assert(!__traits(compiles, ConversionResult!long.State.exactValue));
static assert(!__traits(compiles, ConversionResult!long.withValue(123,ConversionStatus.exact)));
static assert(!__traits(compiles, { ConversionResult!long r; r.state_ = 1; }));
static assert(!__traits(compiles, { ConversionResult!long r; return r.value_; }));
static assert(!__traits(compiles, ExactResult!long(true,123,ExactFailure.overflow)));
static assert(!__traits(compiles, { ExactResult!long r={true,123,ExactFailure.overflow}; }));
static assert(!__traits(compiles, { ExactResult!long r={3,123}; }));
static assert(!__traits(compiles, ExactResult!long.State.value));

enum ctfeCarrierStates = ({
    ConversionResult!long checkedDefault;
    ExactResult!long exactDefault;
    long value;
    ExactFailure failure;
    if (checkedDefault.hasValue || checkedDefault.status != ConversionStatus.inexact
        || checkedDefault.tryValue(value)) return false;
    if (exactDefault.hasValue || exactDefault.tryValue(value)
        || !exactDefault.tryFailure(failure) || failure != ExactFailure.inexact) return false;
    const success = ExactResult!long.success(long.min);
    if (!success.tryValue(value) || value != long.min || success.tryFailure(failure)) return false;
    foreach (expected; [ExactFailure.inexact,ExactFailure.overflow,ExactFailure.nonFinite])
    {
        const failed = ExactResult!long.failed(expected);
        if (failed.hasValue || failed.tryValue(value)
            || !failed.tryFailure(failure) || failure != expected) return false;
    }
    return true;
}());
static assert(ctfeCarrierStates);

// Runtime checks survive -release. Attribute guarantees are checked on the
// actual allocation-free conversion paths, including Quantity payload copying.
@safe pure nothrow @nogc
bool resultCarrierRegression()
{
    const exact = 1250L.checkedQuantity!(Length,InternationalFoot);
    Quantity!(Length,long) integral;
    if (exact.status != ConversionStatus.exact || !exact.tryValue(integral)
        || integral.canonicalValue != 381) return false;
    const copied = exact;
    if (!copied.tryValue(integral) || copied.status != ConversionStatus.exact) return false;
    const fraction = 1L.checkedQuantity!(Length,InternationalFoot);
    if (fraction.status != ConversionStatus.inexact || fraction.hasValue
        || fraction.tryValue(integral)) return false;
    const rounded = (-1L).roundedQuantity!(Length,InternationalFoot,RoundingMode.floor);
    if (rounded.status != ConversionStatus.inexact || !rounded.tryValue(integral)
        || integral.canonicalValue != -1) return false;
    const floating = 1.0.checkedQuantity!(Length,InternationalFoot);
    Quantity!(Length,double) scalar;
    if (floating.status != ConversionStatus.inexact || !floating.tryValue(scalar)) return false;
    const overflow = double.max.checkedQuantity!(Length,Kilometre);
    if (overflow.status != ConversionStatus.overflow || overflow.hasValue
        || overflow.tryValue(scalar)) return false;
    const nonFinite = double.infinity.checkedQuantity!(Length,Metre);
    if (nonFinite.status != ConversionStatus.nonFinite || nonFinite.hasValue
        || nonFinite.tryValue(scalar)) return false;
    const failedExact = double.infinity.exactQuantity!(Length,Metre);
    ExactFailure failure;
    if (failedExact.hasValue || failedExact.tryValue(scalar)
        || !failedExact.tryFailure(failure) || failure != ExactFailure.nonFinite) return false;
    const successExact = long.min.exactQuantity!(Length,Metre);
    if (!successExact.tryValue(integral) || integral.canonicalValue != long.min
        || successExact.tryFailure(failure)) return false;
    return true;
}
