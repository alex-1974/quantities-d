module app;

import std.stdio : writeln;

void main()
{
    int max = int.max;
    int two = 2;
    auto result = max * two;
    writeln("int.max * 2 -> ", typeof(result).stringof, " : ", result);
}
