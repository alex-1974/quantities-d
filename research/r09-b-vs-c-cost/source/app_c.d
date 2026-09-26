module app_c;

import common;

struct QuantityC(Spec, Rep)
{
    Rep value;
}

alias L = QuantityC!(LengthSpec, double);
alias R = QuantityC!(RadiusSpec, double);
alias H = QuantityC!(HeightSpec, double);
alias X = QuantityC!(LinearResolutionSpec, double);

@safe pure nothrow @nogc
QuantityC!(Spec, double) fromUnit(Spec, Unit)(double value)
{
    return QuantityC!(Spec, double)(toMetres!Unit(value));
}

@safe pure nothrow @nogc
double kernelC()
{
    L a = fromUnit!(LengthSpec, Metre)(2.0);
    L b = fromUnit!(LengthSpec, Kilometre)(3.0);
    L c = fromUnit!(LengthSpec, Millimetre)(4000.0);
    L d = fromUnit!(LengthSpec, InternationalFoot)(5.0);
    L e = fromUnit!(LengthSpec, USSurveyFoot)(6.0);

    return a.value + b.value + c.value + d.value + e.value;
}

void main()
{
    import core.stdc.stdio : printf;
    printf("%.12f\n", kernelC());
}
