module r15_source_override_observation;
import quantities.conversion;
import quantities.length : Length,Metre;
import std.stdio : writeln;

// Compile against Probe 15 only. This historical observation is not an
// acceptance requirement for the selected request surface.
static assert(__traits(compiles, ulong.max.checkedQuantityAs!(Length,Metre,long,double)));
static assert(__traits(compiles, 1.checkedQuantityAs!(Length,Metre,float,long)));
void main() { writeln("OBSERVE Probe 15 flat templates accept an explicitly supplied SourceRep"); }
