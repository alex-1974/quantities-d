module app;

struct LengthSpec
{
}

struct RadiusSpec
{
}

struct Metre
{
}

struct Kilometre
{
}

struct Millimetre
{
}

// Candidate A: unit participates in type identity; no separate quantity spec.
struct QuantityA(Unit, Rep)
{
    Rep value;
}

// Candidate B: specification and unit both participate in type identity.
struct QuantityB(Spec, Unit, Rep)
{
    Rep value;
}

// Candidate C: specification participates in value type identity; unit does not.
// This models canonical storage only. Conversion policy is intentionally absent.
struct QuantityC(Spec, Rep)
{
    Rep value;
}

alias AMetre = QuantityA!(Metre, double);
alias AKilometre = QuantityA!(Kilometre, double);

alias BLengthMetre = QuantityB!(LengthSpec, Metre, double);
alias BLengthKilometre = QuantityB!(LengthSpec, Kilometre, double);
alias BRadiusMetre = QuantityB!(RadiusSpec, Metre, double);

alias CLength = QuantityC!(LengthSpec, double);
alias CRadius = QuantityC!(RadiusSpec, double);

static assert(AMetre.sizeof == double.sizeof);
static assert(AKilometre.sizeof == double.sizeof);
static assert(BLengthMetre.sizeof == double.sizeof);
static assert(BLengthKilometre.sizeof == double.sizeof);
static assert(BRadiusMetre.sizeof == double.sizeof);
static assert(CLength.sizeof == double.sizeof);
static assert(CRadius.sizeof == double.sizeof);

static assert(AMetre.alignof == double.alignof);
static assert(BLengthMetre.alignof == double.alignof);
static assert(CLength.alignof == double.alignof);

static assert(!is(AMetre == AKilometre));
static assert(!is(BLengthMetre == BLengthKilometre));
static assert(!is(BLengthMetre == BRadiusMetre));
static assert(!is(CLength == CRadius));

enum aCtfe = AMetre(3.0);
enum bCtfe = BLengthMetre(3.0);
enum cCtfe = CLength(3.0);

static assert(aCtfe.value == 3.0);
static assert(bCtfe.value == 3.0);
static assert(cCtfe.value == 3.0);

@safe pure nothrow @nogc
double boundaryProbe()
{
    const a = AMetre(1.0);
    const b = BLengthMetre(2.0);
    const c = CLength(3.0);
    return a.value + b.value + c.value;
}

static assert(boundaryProbe() == 6.0);

void main() @safe pure nothrow @nogc
{
    assert(boundaryProbe() == 6.0);
}


// ---------------------------------------------------------------------------
// Semantic probe 1: equivalent mixed-unit length arithmetic.
//
// These helpers are intentionally probe-local. They model only enough policy
// to expose what information each representation carries; they are not API
// proposals.
// ---------------------------------------------------------------------------

@safe pure nothrow @nogc
QuantityA!(Metre, Rep) addA(Rep)(
    QuantityA!(Metre, Rep) lhs,
    QuantityA!(Kilometre, Rep) rhs)
{
    return QuantityA!(Metre, Rep)(lhs.value + rhs.value * Rep(1000));
}

@safe pure nothrow @nogc
QuantityB!(Spec, Metre, Rep) addB(Spec, Rep)(
    QuantityB!(Spec, Metre, Rep) lhs,
    QuantityB!(Spec, Kilometre, Rep) rhs)
{
    return QuantityB!(Spec, Metre, Rep)(lhs.value + rhs.value * Rep(1000));
}

@safe pure nothrow @nogc
QuantityC!(Spec, Rep) addC(Spec, Rep)(
    QuantityC!(Spec, Rep) lhs,
    QuantityC!(Spec, Rep) rhs)
{
    return QuantityC!(Spec, Rep)(lhs.value + rhs.value);
}

enum aMixed = addA(AMetre(500.0), AKilometre(1.0));
enum bMixed = addB(BLengthMetre(500.0), BLengthKilometre(1.0));

// C is canonical-storage in this probe: construct both source units explicitly
// at the boundary, then arithmetic no longer carries unit conversion policy.
@safe pure nothrow @nogc
CLength cMetres(double value)
{
    return CLength(value);
}

@safe pure nothrow @nogc
CLength cKilometres(double value)
{
    return CLength(value * 1000.0);
}

enum cMixed = addC(cMetres(500.0), cKilometres(1.0));

static assert(aMixed.value == 1500.0);
static assert(bMixed.value == 1500.0);
static assert(cMixed.value == 1500.0);

// A can distinguish units but has no independent Spec axis: AMetre alone cannot
// encode whether the value is Length, Radius, Height, etc.
//
// B rejects a Radius/Length addition by template deduction because Spec differs.
static assert(!__traits(compiles,
    addB(BLengthMetre(500.0), QuantityB!(RadiusSpec, Kilometre, double)(1.0))));

// C likewise rejects cross-Spec arithmetic even though unit identity has already
// been normalized away at the construction boundary.
static assert(!__traits(compiles,
    addC(CLength(500.0), CRadius(1000.0))));

@safe pure nothrow @nogc
double mixedUnitProbe()
{
    return aMixed.value + bMixed.value + cMixed.value;
}

static assert(mixedUnitProbe() == 4500.0);


// ---------------------------------------------------------------------------
// Semantic probe 2: integer exactness and representation pressure.
//
// B preserves the source-unit value. C canonicalizes at the boundary. Metre /
// millimetre is used because it exposes a bidirectional integer problem without
// relying on floating-point approximation.
// ---------------------------------------------------------------------------

struct Millimetre
{
}

alias BLengthMetreLong = QuantityB!(LengthSpec, Metre, long);
alias BLengthMillimetreLong = QuantityB!(LengthSpec, Millimetre, long);
alias CLengthLong = QuantityC!(LengthSpec, long);

enum bOneMetreLong = BLengthMetreLong(1);
enum bOneMillimetreLong = BLengthMillimetreLong(1);

static assert(bOneMetreLong.value == 1);
static assert(bOneMillimetreLong.value == 1);

// Canonical metres with an integral Rep cannot exactly represent 1 mm.
// The boundary conversion would require 1 / 1000, which truncates for long.
@safe pure nothrow @nogc
CLengthLong cMillimetresLong(long value)
{
    return CLengthLong(value / 1000);
}

enum cOneMillimetreLong = cMillimetresLong(1);
static assert(cOneMillimetreLong.value == 0);

// Canonical millimetres would solve this particular example but simply moves
// the representation choice into the canonical-unit policy. A generic library
// must therefore decide what exactness guarantees canonical storage makes for
// integral Rep values.
@safe pure nothrow @nogc
long metreToMillimetreExact(long value)
{
    return value * 1000;
}

static assert(metreToMillimetreExact(1) == 1000);

// B can retain both integral source representations exactly without choosing a
// common storage unit at construction. Conversion/arithmetic still needs an
// explicit result/loss policy later; this probe makes no claim that B solves
// those questions automatically.
static assert(BLengthMetreLong.sizeof == long.sizeof);
static assert(BLengthMillimetreLong.sizeof == long.sizeof);
static assert(CLengthLong.sizeof == long.sizeof);


// ---------------------------------------------------------------------------
// Consumer probe 1: geodesy-d style projection boundary.
//
// Current geodesy-d makes the ellipsoid semi-major axis define the operation's
// caller-selected linear unit; false offsets and projected coordinates use the
// same unit. This probe compares how B preserves that contract and how C would
// deliberately replace it with canonicalized boundary inputs.
//
// These types/functions are research-only sketches, not proposed public API.
// ---------------------------------------------------------------------------

struct SemiMajorAxisSpec
{
}

struct FalseEastingSpec
{
}

struct FalseNorthingSpec
{
}

alias BAxisMetre = QuantityB!(SemiMajorAxisSpec, Metre, double);
alias BAxisKilometre = QuantityB!(SemiMajorAxisSpec, Kilometre, double);
alias BFalseEastingMetre = QuantityB!(FalseEastingSpec, Metre, double);
alias BFalseEastingKilometre =
    QuantityB!(FalseEastingSpec, Kilometre, double);
alias BFalseNorthingMetre = QuantityB!(FalseNorthingSpec, Metre, double);
alias BFalseNorthingKilometre =
    QuantityB!(FalseNorthingSpec, Kilometre, double);

struct BProjection(Unit)
{
    QuantityB!(SemiMajorAxisSpec, Unit, double) semiMajorAxis;
    QuantityB!(FalseEastingSpec, Unit, double) falseEasting;
    QuantityB!(FalseNorthingSpec, Unit, double) falseNorthing;
}

@safe pure nothrow @nogc
BProjection!Unit makeProjectionB(Unit)(
    QuantityB!(SemiMajorAxisSpec, Unit, double) semiMajorAxis,
    QuantityB!(FalseEastingSpec, Unit, double) falseEasting,
    QuantityB!(FalseNorthingSpec, Unit, double) falseNorthing)
{
    return BProjection!Unit(semiMajorAxis, falseEasting, falseNorthing);
}

enum bProjectionMetre = makeProjectionB(
    BAxisMetre(6_378_137.0),
    BFalseEastingMetre(500_000.0),
    BFalseNorthingMetre(0.0));

static assert(bProjectionMetre.semiMajorAxis.value == 6_378_137.0);
static assert(bProjectionMetre.falseEasting.value == 500_000.0);

// B encodes geodesy-d's current same-linear-unit contract in the type system.
static assert(!__traits(compiles,
    makeProjectionB(
        BAxisMetre(6_378_137.0),
        BFalseEastingKilometre(500.0),
        BFalseNorthingMetre(0.0))));

// C instead represents a canonicalized internal boundary. Different source
// units can be accepted by explicit constructors before the projection is made.
alias CAxis = QuantityC!(SemiMajorAxisSpec, double);
alias CFalseEasting = QuantityC!(FalseEastingSpec, double);
alias CFalseNorthing = QuantityC!(FalseNorthingSpec, double);

struct CProjection
{
    CAxis semiMajorAxis;
    CFalseEasting falseEasting;
    CFalseNorthing falseNorthing;
}

@safe pure nothrow @nogc
CAxis cAxisMetres(double value)
{
    return CAxis(value);
}

@safe pure nothrow @nogc
CFalseEasting cFalseEastingKilometres(double value)
{
    return CFalseEasting(value * 1000.0);
}

@safe pure nothrow @nogc
CFalseNorthing cFalseNorthingMetres(double value)
{
    return CFalseNorthing(value);
}

@safe pure nothrow @nogc
CProjection makeProjectionC(
    CAxis semiMajorAxis,
    CFalseEasting falseEasting,
    CFalseNorthing falseNorthing)
{
    return CProjection(semiMajorAxis, falseEasting, falseNorthing);
}

enum cProjectionMixedSourceUnits = makeProjectionC(
    cAxisMetres(6_378_137.0),
    cFalseEastingKilometres(500.0),
    cFalseNorthingMetres(0.0));

static assert(
    cProjectionMixedSourceUnits.semiMajorAxis.value == 6_378_137.0);
static assert(
    cProjectionMixedSourceUnits.falseEasting.value == 500_000.0);


// ---------------------------------------------------------------------------
// Consumer probe 2: geo-d / geo3-d integer-coordinate exactness.
//
// geo-d deliberately computes integral coordinate differences before
// conversion to its floating metric type. A quantity representation must not
// accidentally destroy that property merely by attaching units.
//
// This probe compares source-unit-preserving B with canonical-storage C.
// It intentionally uses a large long coordinate whose adjacent value cannot
// be distinguished after conversion to double.
// ---------------------------------------------------------------------------

struct CoordinateSpec
{
}

struct DisplacementSpec
{
}

alias BCoordinateMillimetre =
    QuantityB!(CoordinateSpec, Millimetre, long);
alias BDisplacementMillimetre =
    QuantityB!(DisplacementSpec, Millimetre, long);

@safe pure nothrow @nogc
long differenceB(
    BCoordinateMillimetre a,
    BCoordinateMillimetre b)
{
    // Same-unit B retains the source integer representation, so subtraction
    // can happen before any later metric floating-point conversion.
    return a.value - b.value;
}

enum long largeCoordinate = 9_007_199_254_740_992L; // 2^53

enum bLarge = BCoordinateMillimetre(largeCoordinate);
enum bAdjacent = BCoordinateMillimetre(largeCoordinate + 1);

static assert(differenceB(bAdjacent, bLarge) == 1);

// A C design is not intrinsically floating-point. Canonical storage with an
// integral Rep preserves exactness when the source unit maps integrally into
// the canonical unit.
alias CCoordinateLong = QuantityC!(CoordinateSpec, long);

@safe pure nothrow @nogc
CCoordinateLong cCoordinateMillimetres(long value)
{
    return CCoordinateLong(value);
}

@safe pure nothrow @nogc
long differenceC(
    CCoordinateLong a,
    CCoordinateLong b)
{
    return a.value - b.value;
}

enum cLarge = cCoordinateMillimetres(largeCoordinate);
enum cAdjacent = cCoordinateMillimetres(largeCoordinate + 1);

static assert(differenceC(cAdjacent, cLarge) == 1);

// But canonicalization can require a representation change. If the canonical
// unit is metre, an integral millimetre coordinate generally needs a
// fractional representation. Converting large integer source coordinates to
// double before differencing can erase an adjacent-unit difference.
alias CCoordinateDouble = QuantityC!(CoordinateSpec, double);

@safe pure nothrow @nogc
CCoordinateDouble cCoordinateMetresFromMillimetres(long value)
{
    return CCoordinateDouble(cast(double) value / 1000.0);
}

enum cFloatingLarge =
    cCoordinateMetresFromMillimetres(largeCoordinate);
enum cFloatingAdjacent =
    cCoordinateMetresFromMillimetres(largeCoordinate + 1);

static assert(
    cFloatingAdjacent.value == cFloatingLarge.value,
    "probe expects early floating canonicalization to lose adjacency");

// This is not a proof against C. It demonstrates that C requires an explicit
// representation/conversion policy: canonical unit choice and Rep choice can
// affect exact integer-coordinate semantics before geometry sees the values.
