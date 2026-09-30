module r15_composed_runner;

import r15_composed_kernel;
import r15_rescale_kernel : Status,storedBits;
import std.conv : to;
import std.stdio : stdin,writeln;
import std.string : split;

@safe pure nothrow @nogc
void attributes()
{
    const r=convertComposedExact!float(1,0,false,2,3,1,1);
    assert(r.status==Status.inexact);
}

void emit(T)(ulong sig,int exp,bool neg,long fn,long fd,long tn,long td)
{
    const r=convertComposedExact!T(sig,exp,neg,fn,fd,tn,td);
    int nb,db;
    composedWidths(sig,fn,fd,tn,td,nb,db);
    if (r.status==Status.overflow)
        writeln(r.status," - ",nb," ",db);
    else
        writeln(r.status," ",storedBits(r.value)," ",nb," ",db);
}

void main()
{
    attributes();
    foreach (line;stdin.byLineCopy)
    {
        const f=line.split;
        const sig=f[1].to!ulong;
        const exp=f[2].to!int;
        const neg=f[3]=="1";
        const fn=f[4].to!long,fd=f[5].to!long;
        const tn=f[6].to!long,td=f[7].to!long;
        if(f[0]=="F") emit!float(sig,exp,neg,fn,fd,tn,td);
        else emit!double(sig,exp,neg,fn,fd,tn,td);
    }
}
