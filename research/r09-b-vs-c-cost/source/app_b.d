module app_b;

import common;

struct QuantityB(Spec, Unit, Rep)
{
    Rep value;
}

alias LM = QuantityB!(LengthSpec, Metre, double);
alias LKM = QuantityB!(LengthSpec, Kilometre, double);
alias LMM = QuantityB!(LengthSpec, Millimetre, double);
alias LIF = QuantityB!(LengthSpec, InternationalFoot, double);
alias LSF = QuantityB!(LengthSpec, USSurveyFoot, double);

alias RM = QuantityB!(RadiusSpec, Metre, double);
alias RKM = QuantityB!(RadiusSpec, Kilometre, double);
alias RMM = QuantityB!(RadiusSpec, Millimetre, double);
alias RIF = QuantityB!(RadiusSpec, InternationalFoot, double);
alias RSF = QuantityB!(RadiusSpec, USSurveyFoot, double);

alias HM = QuantityB!(HeightSpec, Metre, double);
alias HKM = QuantityB!(HeightSpec, Kilometre, double);
alias HMM = QuantityB!(HeightSpec, Millimetre, double);
alias HIF = QuantityB!(HeightSpec, InternationalFoot, double);
alias HSF = QuantityB!(HeightSpec, USSurveyFoot, double);

alias XM = QuantityB!(LinearResolutionSpec, Metre, double);
alias XKM = QuantityB!(LinearResolutionSpec, Kilometre, double);
alias XMM = QuantityB!(LinearResolutionSpec, Millimetre, double);
alias XIF = QuantityB!(LinearResolutionSpec, InternationalFoot, double);
alias XSF = QuantityB!(LinearResolutionSpec, USSurveyFoot, double);

@safe pure nothrow @nogc
double kernelB()
{
    LM a = LM(2.0);
    LKM b = LKM(3.0);
    LMM c = LMM(4000.0);
    LIF d = LIF(5.0);
    LSF e = LSF(6.0);

    return a.value
        + toMetres!Kilometre(b.value)
        + toMetres!Millimetre(c.value)
        + toMetres!InternationalFoot(d.value)
        + toMetres!USSurveyFoot(e.value);
}

void main()
{
    import core.stdc.stdio : printf;
    printf("%.12f\n", kernelB());
}
