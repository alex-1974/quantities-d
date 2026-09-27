module app;

import std.stdio : writeln;

void main()
{
    int value = int.min;
    int minusOne = -1;
    auto result = value / minusOne;
    writeln("int.min / -1 -> ", typeof(result).stringof, " : ", result);
}
