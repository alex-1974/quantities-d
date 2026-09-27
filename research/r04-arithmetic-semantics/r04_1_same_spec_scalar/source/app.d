module app;

import std.stdio : writeln;

struct ProbeQ(R)
{
    R value;

    auto opBinary(string op, R2)(ProbeQ!R2 rhs) const
        if (op == "+" || op == "-")
    {
        alias Result = typeof(mixin("value " ~ op ~ " rhs.value"));
        return ProbeQ!Result(mixin("value " ~ op ~ " rhs.value"));
    }

    auto opBinary(string op, S)(S scalar) const
        if ((op == "*" || op == "/") && !is(S == ProbeQ!T, T))
    {
        alias Result = typeof(mixin("value " ~ op ~ " scalar"));
        return ProbeQ!Result(mixin("value " ~ op ~ " scalar"));
    }

    auto opBinaryRight(string op, S)(S scalar) const
        if (op == "*")
    {
        alias Result = typeof(mixin("scalar " ~ op ~ " value"));
        return ProbeQ!Result(mixin("scalar " ~ op ~ " value"));
    }
}

template repName(T)
{
    enum repName = T.stringof;
}

void showBinary(A, B)(string label, A a, B b)
{
    auto sum = ProbeQ!A(a) + ProbeQ!B(b);
    auto difference = ProbeQ!A(a) - ProbeQ!B(b);
    writeln(label, " + -> ", repName!(typeof(sum.value)), " : ", sum.value);
    writeln(label, " - -> ", repName!(typeof(difference.value)), " : ", difference.value);
}

void showScalar(A, B)(string label, A a, B b)
{
    auto product = ProbeQ!A(a) * b;
    auto reverseProduct = b * ProbeQ!A(a);
    auto quotient = ProbeQ!A(a) / b;
    writeln(label, " * -> ", repName!(typeof(product.value)), " : ", product.value);
    writeln(label, " r* -> ", repName!(typeof(reverseProduct.value)), " : ", reverseProduct.value);
    writeln(label, " / -> ", repName!(typeof(quotient.value)), " : ", quotient.value);
}

@safe pure nothrow @nogc
auto ctfeSameRep()
{
    return ProbeQ!int(12) + ProbeQ!int(5);
}

static assert(ctfeSameRep().value == 17);

void main()
{
    showBinary("int/int", 12, 5);
    showBinary("int/long", 12, 5L);
    showBinary("int/uint", 12, 5U);
    showBinary("int/double", 12, 5.5);
    showBinary("float/double", 12.0f, 5.5);

    showScalar("int*int", 12, 5);
    showScalar("int*long", 12, 5L);
    showScalar("int*double", 12, 2.5);
    showScalar("float*double", 12.0f, 2.5);
}
