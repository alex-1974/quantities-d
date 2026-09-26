module common;

struct LengthSpec {}
struct RadiusSpec {}
struct HeightSpec {}
struct LinearResolutionSpec {}

struct Metre {}
struct Kilometre {}
struct Millimetre {}
struct InternationalFoot {}
struct USSurveyFoot {}

enum double toMetres(Unit)(double value)
{
    static if (is(Unit == Metre))
        return value;
    else static if (is(Unit == Kilometre))
        return value * 1000.0;
    else static if (is(Unit == Millimetre))
        return value / 1000.0;
    else static if (is(Unit == InternationalFoot))
        return value * 381.0 / 1250.0;
    else static if (is(Unit == USSurveyFoot))
        return value * 1200.0 / 3937.0;
    else
        static assert(false, "unsupported probe unit");
}
