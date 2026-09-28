module app;

import std.stdio : writeln, writefln;

void probe(T, S)(T value, S divisor)
{
    writefln("%s / %s : %s / %s = %s",
        T.stringof, S.stringof, value, divisor, value / divisor);
}

void main()
{
    writeln("=== exact ===");
    probe(int(6), int(3));
    probe(uint(6), uint(3));
    probe(int(-6), int(3));
    probe(int(6), int(-3));

    writeln("=== inexact ===");
    probe(int(5), int(2));
    probe(int(-5), int(2));
    probe(int(5), int(-2));
    probe(uint(5), uint(2));

    writeln("=== mixed signedness ===");
    probe(int(5), uint(2));
    probe(uint(5), int(2));
}
