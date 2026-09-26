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
