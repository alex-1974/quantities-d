module app;

import std.stdio : writeln;

void main()
{
    int value = 1;
    int zero = 0;
    auto result = value / zero;
    writeln("1 / 0 -> ", result);
}
