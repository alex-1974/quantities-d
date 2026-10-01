module r15_integral_source_codegen;
import quantities.conversion;
import quantities.quantity : Quantity;
import quantities.length : Length,Metre,InternationalFoot;
import r15_composed_kernel : convertComposedLong,IntegralRoundingMode;

ulong requested(Unit,bool rounded,S)(S source) @safe pure nothrow @nogc
{
    static if(rounded) const r=source.roundedQuantityAs!(Length,Unit,long,RoundingMode.floor);
    else const r=source.checkedQuantityAs!(Length,Unit,long);
    Quantity!(Length,long) value;
    return r.tryValue(value)?cast(ulong)value.canonicalValue:ulong.max;
}
ulong baseline(Unit,bool rounded,S)(S source) @safe pure nothrow @nogc
{
    static if(is(S==long))
    {
        const negative=source<0;
        const magnitude=negative ? cast(ulong)(-(source+1))+1UL : cast(ulong)source;
    }
    else { enum negative=false; const magnitude=source; }
    const r=convertComposedLong(magnitude,0,negative,Unit.Scale.numerator,Unit.Scale.denominator,1,1,rounded,IntegralRoundingMode.floor);
    return r.hasValue?cast(ulong)r.value:ulong.max;
}
extern(C):
pragma(inline,false) ulong r15LongLong(long v) {return requested!(Metre,false)(v);}
pragma(inline,false) ulong r15UlongLong(ulong v) {return requested!(Metre,false)(v);}
pragma(inline,false) ulong r15UlongLongFloor(ulong v) {return requested!(Metre,true)(v);}
pragma(inline,false) ulong r15LongFootFloor(long v) {return requested!(InternationalFoot,true)(v);}
pragma(inline,false) ulong r15BaselineLongLong(long v) {return baseline!(Metre,false)(v);}
pragma(inline,false) ulong r15BaselineUlongLong(ulong v) {return baseline!(Metre,false)(v);}
pragma(inline,false) ulong r15BaselineUlongLongFloor(ulong v) {return baseline!(Metre,true)(v);}
pragma(inline,false) ulong r15BaselineLongFootFloor(long v) {return baseline!(InternationalFoot,true)(v);}
