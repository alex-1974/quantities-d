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
