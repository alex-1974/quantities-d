module quantities.verification;
import quantities.exact_conversion;
import std.conv : to;
import std.math : ldexp;
import std.stdio : stdin, writeln;
import std.string : split;

void emit(T,S)(S source,long fn,long fd,long tn,long td)
{
    const result = convertFloating!T(source,fn,fd,tn,td);
    if (result.status == Status.overflow || result.status == Status.nonFinite)
        writeln(result.status," -");
    else writeln(result.status," ",storedBits(result.value));
}

void source(T)(const(string)[] f)
{
    const fn=f[$-4].to!long,fd=f[$-3].to!long,tn=f[$-2].to!long,td=f[$-1].to!long;
    switch (f[1])
    {
        case "L": emit!T(f[2].to!long,fn,fd,tn,td); break;
        case "U": emit!T(f[2].to!ulong,fn,fd,tn,td); break;
        case "F": emit!T(fromBits!float(f[2].to!ulong),fn,fd,tn,td); break;
        case "D": emit!T(fromBits!double(f[2].to!ulong),fn,fd,tn,td); break;
        default:
            static if (qualifiedReal)
            {
                real value;
                if (f[1]=="R")
                {
                    value=ldexp(cast(real)f[2].to!ulong,f[3].to!int);
                    if (f[4]=="1") value=-value;
                }
                else if (f[1]=="N") value=real.nan;
                else if (f[1]=="P") value=real.infinity;
                else if (f[1]=="M") value=-real.infinity;
                else assert(false);
                emit!T(value,fn,fd,tn,td);
            }
            else assert(false);
    }
}

void main(string[] args)
{
    if (args.length>1) { writeln(real.mant_dig," ",real.min_exp," ",real.max_exp); return; }
    foreach (line;stdin.byLineCopy)
    {
        const f=line.split;
        if (f[0]=="F") source!float(f);
        else source!double(f);
    }
}
