module r15_carrier_observation;
import quantities.conversion : ConversionResult,ConversionStatus,ExactResult,ExactFailure;
import std.stdio : writeln;

// Compile against actual production, not the hardened research shadow.
// OBSERVE is evidence of current behavior, never an acceptance requirement.
enum forged = ConversionResult!long(true,123,ConversionStatus.overflow);
static assert(forged.hasValue && forged.status == ConversionStatus.overflow);
enum forgedExact = ExactResult!long(true,123,ExactFailure.overflow);
static assert(forgedExact.hasValue);
void main()
{
    long value;
    if(!forged.tryValue(value) || value!=123)
        throw new Exception("unexpected production carrier observation");
    writeln("R15 Probe 14 OBSERVE: production ConversionResult accepts overflow + payload via positional construction; ExactResult accepts positional construction");
}
