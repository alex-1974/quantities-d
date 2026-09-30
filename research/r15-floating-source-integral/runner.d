module r15_floating_integral_runner;
import r15_floating_integral_kernel;
import r15_composed_kernel : IntegralRoundingMode;
import r15_rescale_kernel : Status, fromBits;
import std.conv : to;
import std.math : ldexp;
import std.stdio : stdin, writeln;
import std.string : split;

static assert(!__traits(compiles, convertFloatingLong(1L,1,1,1,1,false,
    IntegralRoundingMode.towardZero)));
static assert(!__traits(compiles, convertFloatingLong(ulong.max,1,1,1,1,false,
    IntegralRoundingMode.towardZero)));
static assert(!__traits(compiles, convertFloatingLong("1",1,1,1,1,false,
    IntegralRoundingMode.towardZero)));
// Ordinary represented float/double source reconstruction remains runtime-only.
static assert(!__traits(compiles, {
    enum r = convertFloatingLong(1.5,1,1,1,1,true,
        IntegralRoundingMode.floor);
}));

@safe pure nothrow @nogc
void attributes()
{
    const(float) f = -1.5F;
    immutable(double) d = 1.5;
    const rf = convertFloatingLong(f,1,1,1,1,true,IntegralRoundingMode.floor);
    const rd = convertFloatingLong(d,1,1,1,1,true,IntegralRoundingMode.ceiling);
    assert(rf.hasValue && rf.value == -2 && rf.status == Status.inexact);
    assert(rd.hasValue && rd.value == 2 && rd.status == Status.inexact);
    static if (qualifiedReal)
    {
        const(real) r = -1.5L;
        const rr = convertFloatingLong(r,1,1,1,1,true,
            IntegralRoundingMode.nearestTiesAway);
        assert(rr.hasValue && rr.value == -2 && rr.status == Status.inexact);
    }
}

void emit(S)(S source,long fn,long fd,long tn,long td,bool rounded,int mode)
{
    const r = convertFloatingLong(source,fn,fd,tn,td,rounded,
        cast(IntegralRoundingMode)mode);
    if (r.hasValue) writeln(r.status," ",r.value);
    else writeln(r.status," -");
}

void main(string[] args)
{
    if (args.length > 1)
    {
        writeln(real.mant_dig," ",real.min_exp," ",real.max_exp);
        return;
    }
    attributes();
    foreach (line;stdin.byLineCopy)
    {
        const f = line.split;
        const fn = f[$-4].to!long, fd = f[$-3].to!long;
        const tn = f[$-2].to!long, td = f[$-1].to!long;
        const rounded = f[1] == "R";
        const mode = f[2].to!int;
        if (f[0] == "F") emit(fromBits!float(f[3].to!ulong),fn,fd,tn,td,rounded,mode);
        else if (f[0] == "D") emit(fromBits!double(f[3].to!ulong),fn,fd,tn,td,rounded,mode);
        else static if (qualifiedReal)
        {
            real source;
            if (f[0] == "R")
            {
                source = ldexp(cast(real)f[3].to!ulong,f[4].to!int);
                if (f[5] == "1") source = -source;
            }
            else if (f[0] == "N") source = real.nan;
            else if (f[0] == "P") source = real.infinity;
            else if (f[0] == "M") source = -real.infinity;
            else assert(false,"unknown source");
            emit(source,fn,fd,tn,td,rounded,mode);
        }
        else assert(false,"unqualified real source");
    }
}
