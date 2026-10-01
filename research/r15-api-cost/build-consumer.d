module r15_build_consumer;
import quantities.conversion;
import quantities.quantity : Quantity,quantity;
import quantities.length : Length,Metre,InternationalFoot;
import std.stdio : writeln;

ulong requests(double source,ulong integer,float narrow)
{
    const c1=source.checkedQuantityAs!(Length,InternationalFoot,float);
    const c2=integer.checkedQuantityAs!(Length,Metre,double);
    const c3=narrow.checkedQuantityAs!(Length,Metre,double);
    const e=source.exactQuantityAs!(Length,Metre,float);
    const r=source.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor);
    const q=source.quantity!(Length,Metre);
    const qc=q.checkedInAs!(InternationalFoot,float);
    const qe=q.exactInAs!(Metre,float);
    const qr=q.roundedInAs!(Metre,long,RoundingMode.floor);
    return cast(ulong)c1.status+cast(ulong)c2.status+cast(ulong)c3.status+
        cast(ulong)c1.hasValue+cast(ulong)c2.hasValue+cast(ulong)c3.hasValue+
        cast(ulong)e.hasValue+cast(ulong)r.status+cast(ulong)qc.status+
        cast(ulong)qe.hasValue+cast(ulong)qr.status;
}
void main(string[] args)
{
    writeln(requests(cast(double)args.length,cast(ulong)args.length,cast(float)args.length));
}
