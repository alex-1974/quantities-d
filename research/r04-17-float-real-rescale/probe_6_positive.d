module r04_17_probe_6_positive;

import std.stdio : writeln;

void main()
{
    enum float identityProduct = 1.5f * 2.0f;
    enum float identityQuotient = 3.0f / 2.0f;

    static assert(identityProduct == 3.0f);
    static assert(identityQuotient == 1.5f);

    writeln("R04.17 Probe 6 native/identity CTFE PASS");
}
