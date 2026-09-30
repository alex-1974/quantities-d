module r15_probe_9_public_overflow_status;

import std.stdio : writeln;
import quantities;

enum long denominator = 1L << 62;
enum long numerator = denominator + 1L;

alias SlightlyLargeMetre = DerivedUnit!(
    LengthDimension,
    ExactRatio!(numerator, denominator));

void main()
{
    auto result =
        double.max.checkedQuantity!(
            Length,
            SlightlyLargeMetre);

    writeln("checkedQuantity hasValue: ", result.hasValue);
    writeln("checkedQuantity status:   ", result.status);

    Quantity!(Length, double) value;
    if (result.tryValue(value))
        writeln("canonical == double.max: ", value.canonicalValue == double.max);

    // Observation only. The expected ADR-0005 outcome is overflow because the
    // exact mathematical canonical value is strictly greater than double.max.
    writeln(
        "R15 Probe 9 OBSERVE: public checked conversion "
        ~ "status at mathematical range boundary");
}
