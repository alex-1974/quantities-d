module r04_17_probe_5_ieee;

import std.stdio : writeln;

import r04_17_binary32_kernel :
    inputFromBits,
    rescaleProductBinary32,
    rescaleQuotientBinary32,
    resultBits;

private enum Class
{
    zero,
    finite,
    infinity,
    nan
}

private Class classify(float value)
{
    const bits = resultBits(value);
    const exp = (bits >> 23) & 0xffU;
    const frac = bits & 0x7fffffU;

    if (exp == 0xffU)
        return frac == 0 ? Class.infinity : Class.nan;

    if ((bits & 0x7fff_ffffU) == 0)
        return Class.zero;

    return Class.finite;
}

private bool signBit(float value)
{
    return (resultBits(value) >> 31) != 0;
}

private bool dispatchSpecial(float value)
{
    const c = classify(value);
    return c == Class.zero
        || c == Class.infinity
        || c == Class.nan;
}

private void compareSpecial(
    string op,
    float lhs,
    float rhs)
{
    assert(dispatchSpecial(lhs) || dispatchSpecial(rhs));

    float actual;
    float native;

    if (op == "P")
    {
        actual = rescaleProductBinary32(lhs, rhs, 2, 3);
        native = lhs * rhs;
    }
    else
    {
        actual = rescaleQuotientBinary32(lhs, rhs, 2, 3);
        native = lhs / rhs;
    }

    const actualClass = classify(actual);
    const nativeClass = classify(native);

    assert(actualClass == nativeClass);

    if (actualClass == Class.nan)
        return;

    assert(signBit(actual) == signBit(native));

    if (actualClass == Class.zero
        || actualClass == Class.infinity)
    {
        assert(resultBits(actual) == resultBits(native));
    }
}

void main()
{
    const values = [
        inputFromBits(0x00000000U), // +0
        inputFromBits(0x80000000U), // -0
        inputFromBits(0x00000001U), // +min subnormal
        inputFromBits(0x80000001U), // -min subnormal
        inputFromBits(0x3f800000U), // +1
        inputFromBits(0xbf800000U), // -1
        inputFromBits(0x7f800000U), // +Inf
        inputFromBits(0xff800000U), // -Inf
        inputFromBits(0x7fc00001U), // NaN
    ];

    size_t productCases;
    size_t quotientCases;

    foreach (lhs; values)
    {
        foreach (rhs; values)
        {
            if (!dispatchSpecial(lhs) && !dispatchSpecial(rhs))
                continue;

            compareSpecial("P", lhs, rhs);
            compareSpecial("Q", lhs, rhs);

            ++productCases;
            ++quotientCases;
        }
    }

    writeln("product special cases: ", productCases);
    writeln("quotient special cases: ", quotientCases);
    writeln("R04.17 Probe 5 PASS: IEEE special-value dispatch");
}
