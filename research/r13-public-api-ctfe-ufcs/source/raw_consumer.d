module raw_consumer;

import r13_core : Length, Metre, Quantity, quantity;

version (ValidPublicConstruction)
{
    enum q = 2.0.quantity!(Length, Metre);
    static assert(q.canonicalValue == 2.0);
}

version (RawConstructor)
{
    auto q = Quantity!(Length, double)(2.0);
}

version (RawField)
{
    auto q = Quantity!(Length, double).init;
    auto x = q.canonical_;
}

void main() {}
