module app;

import std.math : isNaN;
import std.stdio : writeln;

double direct()
{
    return double.infinity + -double.infinity;
}

double parameters(double a, double b)
{
    return a + b;
}

double locals()
{
    double a = double.infinity;
    double b = -double.infinity;
    return a + b;
}

__gshared double positiveInfinity = double.infinity;
__gshared double negativeInfinity = -double.infinity;

double memoryValues()
{
    return positiveInfinity + negativeInfinity;
}

void report(string name, double value)
{
    writeln(name, ": value=", value, " nan=", isNaN(value));
}

void main()
{
    report("direct constants", direct());
    report("parameters", parameters(double.infinity, -double.infinity));
    report("locals", locals());
    report("global memory", memoryValues());
}
