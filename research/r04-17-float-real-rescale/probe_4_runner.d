module r04_17_probe_4_runner;

import std.conv : to;
import std.stdio : stdin, writeln;
import std.string : split, strip;

import r04_17_binary32_kernel :
    inputFromBits,
    rescaleProductBinary32,
    rescaleQuotientBinary32,
    resultBits;

void main()
{
    foreach (line; stdin.byLineCopy)
    {
        const fields = line.strip.split;
        if (fields.length == 0)
            continue;

        const op = fields[0];
        const lhsBits = fields[1].to!uint;
        const rhsBits = fields[2].to!uint;
        const numerator = fields[3].to!long;
        const denominator = fields[4].to!long;

        const lhs = inputFromBits(lhsBits);
        const rhs = inputFromBits(rhsBits);

        float result;

        if (op == "P")
        {
            result = rescaleProductBinary32(
                lhs,
                rhs,
                numerator,
                denominator);
        }
        else
        {
            assert(op == "Q");
            result = rescaleQuotientBinary32(
                lhs,
                rhs,
                numerator,
                denominator);
        }

        writeln(resultBits(result));
    }
}
