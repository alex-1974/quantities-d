module conversion_as_contract;
import quantities;






struct OtherTag {}
struct WrongUnit { alias Dimension = BaseDimension!OtherTag; alias Scale = ExactRatio!(1,1); }
struct BrokenSpec {}
struct BrokenUnit {}
struct ZeroUnit { alias Dimension = Metre.Dimension; alias Scale = ExactRatio!(0,1); }
struct FractionalMetadata
{
    alias Dimension = Metre.Dimension;
    struct Scale { enum numerator = 1.5; enum denominator = 1.0; }
}

static assert(Quantity!(Length,long).sizeof == long.sizeof);
static assert(!__traits(compiles, ConversionResult!long(true,1,ConversionStatus.exact)));
static assert(!__traits(compiles, { ConversionResult!long r={true,1,ConversionStatus.overflow}; }));
static assert(!__traits(compiles, { ConversionResult!long r={1,123}; }));
static assert(!__traits(compiles, ConversionResult!long.State.exactValue));
static assert(!__traits(compiles, ConversionResult!long.withValue(1,ConversionStatus.exact)));
static assert(!__traits(compiles, ConversionResult!long.withoutValue(ConversionStatus.exact)));
static assert(!__traits(compiles, { ConversionResult!long r; r.status_ = ConversionStatus.exact; }));
static assert(!__traits(compiles, { ConversionResult!long r; return r.value_; }));
static assert(!__traits(compiles, ExactResult!long(true,1,ExactFailure.inexact)));
static assert(!__traits(compiles, { ExactResult!long r={true,1,ExactFailure.overflow}; }));
static assert(!__traits(compiles, { ExactResult!long r={3,123}; }));
static assert(!__traits(compiles, { ExactResult!long r; r.hasValue_ = true; }));
static assert(!__traits(compiles, Quantity!(Length,long).fromCanonical(1)));

static assert(!__traits(compiles, 1.0.checkedQuantityAs!(Length,WrongUnit,long)));
static assert(!__traits(compiles, 1.0.checkedQuantityAs!(BrokenSpec,Metre,long)));
static assert(!__traits(compiles, 1.0.checkedQuantityAs!(Length,BrokenUnit,long)));
static assert(!__traits(compiles, 1.0.checkedQuantityAs!(Length,ZeroUnit,long)));
static assert(!__traits(compiles, 1.0.checkedQuantityAs!(Length,FractionalMetadata,long)));
static assert(!__traits(compiles, 1.0.checkedQuantityAs!(Length,Metre,ulong)));
static assert(!__traits(compiles, 1.0.roundedQuantityAs!(Length,Metre,double,RoundingMode.floor)));
static assert(!__traits(compiles, 1.0.roundedQuantityAs!(Length,Metre,long,cast(RoundingMode)99)));
static assert(__traits(compiles, 1L.checkedQuantityAs!(Length,Metre,long)));
static assert(__traits(compiles, ulong.max.exactQuantityAs!(Length,Metre,long)));
static assert(!__traits(compiles, "1".roundedQuantityAs!(Length,Metre,long,RoundingMode.floor)));
static assert(!__traits(compiles, { auto q=1.0.quantity!(Length,Metre); return q.checkedInAs!(WrongUnit,long); }));
static assert(__traits(compiles, { auto q=1L.quantity!(Length,Metre); return q.checkedInAs!(Metre,long); }));
static assert(!__traits(compiles, { enum r=1.5.checkedQuantityAs!(Length,Metre,long); }));

// Carrier default-state and exact failure gates remain CTFE-compatible.
enum defaults = ({
    ConversionResult!long c;
    ExactResult!long e;
    long value;
    ExactFailure failure;
    return !c.hasValue && c.status == ConversionStatus.inexact && !c.tryValue(value)
        && !e.hasValue && !e.tryValue(value) && e.tryFailure(failure)
        && failure == ExactFailure.inexact;
}());
static assert(defaults);

// Returns evidence instead of assert so release builds execute every check.
@safe pure nothrow @nogc
bool consumerChecks()
{
    const(float) source = -1.5F;
    immutable(double) positive = 1.5;
    const checked = source.checkedQuantityAs!(Length,Metre,long);
    if (checked.hasValue || checked.status != ConversionStatus.inexact) return false;
    Quantity!(Length,long) value;
    if (checked.tryValue(value)) return false;
    const rounded = source.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor);
    if (rounded.status != ConversionStatus.inexact || !rounded.tryValue(value)
        || value.canonicalValue != -2) return false;
    const exact = positive.exactQuantityAs!(Length,Metre,long);
    ExactFailure failure;
    if (exact.hasValue || !exact.tryFailure(failure) || failure != ExactFailure.inexact) return false;
    double scalar = -1.5;
    const q = scalar.quantity!(Length,Metre);
    const extraction = q.roundedInAs!(Metre,long,RoundingMode.nearestTiesAway);
    long extracted;
    if (extraction.status != ConversionStatus.inexact || !extraction.tryValue(extracted)
        || extracted != -2) return false;
    const bad = double.infinity.checkedQuantityAs!(Length,InternationalFoot,long);
    if (bad.hasValue || bad.status != ConversionStatus.nonFinite) return false;
    const overflow = double.max.exactQuantityAs!(Length,Metre,long);
    if (overflow.hasValue || !overflow.tryFailure(failure) || failure != ExactFailure.overflow) return false;
    const ok = 2.0.exactQuantityAs!(Length,Metre,long);
    if (!ok.tryValue(value) || value.canonicalValue != 2 || ok.tryFailure(failure)) return false;
    // Existing source-preserving production operation remains available.
    const legacy = 2.0.checkedQuantity!(Length,Metre);
    Quantity!(Length,double) legacyValue;
    if (!legacy.tryValue(legacyValue) || legacyValue.canonicalValue != 2.0) return false;
    return true;
}


// All outer request lists reject a Source override; extraction likewise deduces Spec.
static assert(!__traits(compiles, checkedQuantityAs!(Length,Metre,long,ulong)(1UL)));
static assert(!__traits(compiles, exactQuantityAs!(Length,Metre,long,ulong)(1UL)));
static assert(!__traits(compiles, roundedQuantityAs!(Length,Metre,long,RoundingMode.floor,ulong)(1UL)));
static assert(!__traits(compiles, checkedInAs!(Metre,long,Length)(1L.quantity!(Length,Metre))));
static assert(!__traits(compiles, exactInAs!(Metre,long,Length)(1L.quantity!(Length,Metre))));
static assert(!__traits(compiles, roundedInAs!(Metre,long,RoundingMode.floor,Length)(1L.quantity!(Length,Metre))));

// All ordinary floating requests remain runtime-only, including identity and NF.
static foreach (S; float, double, real)
{
    static foreach (T; long, float, double)
    {
        static assert(!__traits(compiles, { enum r = (cast(S)1.0).checkedQuantityAs!(Length,Metre,T); }));
        static assert(!__traits(compiles, { enum r = (cast(S)1.0).exactQuantityAs!(Length,Metre,T); }));
        static assert(!__traits(compiles, { enum r = S.nan.checkedQuantityAs!(Length,Metre,T); }));
        static assert(!__traits(compiles, {
            enum q = (cast(S)1.0).quantity!(Length,Metre);
            enum r = q.checkedInAs!(Metre,T);
        }));
    }
    static assert(!__traits(compiles, { enum r = (cast(S)1.5).roundedQuantityAs!(Length,Metre,long,RoundingMode.floor); }));
    static assert(!__traits(compiles, {
        enum q = (cast(S)1.5).quantity!(Length,Metre);
        enum r = q.roundedInAs!(Metre,long,RoundingMode.floor);
    }));
}
static foreach (S; long, ulong)
{
    static foreach (T; float, double)
    {
        static assert(!__traits(compiles, { enum r = (cast(S)1).checkedQuantityAs!(Length,Metre,T); }));
        static assert(!__traits(compiles, { enum r = (cast(S)1).exactQuantityAs!(Length,Metre,T); }));
        static assert(!__traits(compiles, {
            enum q = (cast(S)1).quantity!(Length,Metre);
            enum r = q.exactInAs!(Metre,T);
        }));
    }
}


// Positive controls for the full selected matrix and public payload types.
static foreach (S; long, ulong, float, double, real)
{
    static if (!is(S == real) ||
        (real.mant_dig == 64 && real.min_exp == -16381 && real.max_exp == 16384) ||
        (real.mant_dig == 53 && real.min_exp == -1021 && real.max_exp == 1024))
    {
        static foreach (T; long, float, double)
        {
            static assert(is(typeof(checkedQuantityAs!(Length,Metre,T)(S.init)) == ConversionResult!(Quantity!(Length,T))));
            static assert(is(typeof(exactQuantityAs!(Length,Metre,T)(S.init)) == ExactResult!(Quantity!(Length,T))));
            static assert(is(typeof(checkedInAs!(Metre,T)(S.init.quantity!(Length,Metre))) == ConversionResult!T));
            static assert(is(typeof(exactInAs!(Metre,T)(S.init.quantity!(Length,Metre))) == ExactResult!T));
        }
    }
}
