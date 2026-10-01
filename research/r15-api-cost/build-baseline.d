module r15_build_baseline;
import quantities.conversion;
import quantities.quantity : Quantity,quantity;
import quantities.length : Length,Metre,InternationalFoot;
import std.stdio : writeln;
void main(string[] args) { writeln(cast(ulong)args.length); }
