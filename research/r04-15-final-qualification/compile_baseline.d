module r04_15_compile_baseline;

import quantities;

extern(C)
double compile_baseline(double a, double b)
    @safe pure nothrow @nogc
{
    // Keep the same public package import as the template probe.
    return a + b;
}
