module app;

import quantities;

struct LengthDimension {}

struct Metre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1, 1);
}

struct Kilometre
{
    alias Dimension = LengthDimension;
    alias Scale = ExactRatio!(1000, 1);
}

struct Length
{
    alias Dimension = LengthDimension;
    alias CanonicalUnit = Metre;
}

void main()
{
    enum ctfe = 1.25.quantity!(Length, Kilometre);
    static assert(ctfe.canonicalValue == 1250.0);
    static assert(ctfe.inUnit!Kilometre == 1.25);

    auto runtime = 2.5.quantity!(Length, Metre);
    assert(runtime.canonicalValue == 2.5);

    auto integral = 7L.quantity!(Length, Metre);
    assert(integral.canonicalValue == 7L);

    static assert(Quantity!(Length, double).sizeof == double.sizeof);
}
