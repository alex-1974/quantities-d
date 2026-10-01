module r15_identity_runner;
import r15_identity_consumer : identityChecks;
import quantities.conversion;
import quantities.quantity : Quantity,quantity;
import quantities.length : Length,Metre;
import r15_rescale_kernel : fromBits,storedBits;
import std.stdio : stdin,write,writeln;
import std.string : split;
import std.conv : to;

void emit(T,S)(S source)
{
    const constructed=source.checkedQuantityAs!(Length,Metre,T);
    const q=source.quantity!(Length,Metre);
    const extracted=q.checkedInAs!(Metre,T);
    Quantity!(Length,T) value;
    T scalar;
    write(constructed.status," ");
    if(constructed.tryValue(value)) write(storedBits(value.canonicalValue));
    else write("-");
    write(" | ",extracted.status," ");
    if(extracted.tryValue(scalar)) write(storedBits(scalar));
    else write("-");
}
void main()
{
    if(!identityChecks()) throw new Exception("identity consumer gate failed");
    foreach(line;stdin.byLineCopy)
    {
        const f=line.split;
        const raw=f[1].to!ulong;
        if(f[0]=="F")
        {
            const source=fromBits!float(raw);
            emit!float(source); write(" | "); emit!double(source);
        }
        else emit!double(fromBits!double(raw));
        writeln();
    }
}
