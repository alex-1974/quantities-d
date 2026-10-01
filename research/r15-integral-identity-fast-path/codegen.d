module r15_integral_identity_codegen;
import quantities.conversion;
import quantities.quantity : Quantity;
import quantities.length : Length,Metre;
import r15_floating_integral_kernel : convertFloatingLong,qualifiedReal;
import r15_composed_kernel : IntegralRoundingMode;

@safe pure nothrow @nogc
ulong requested(bool rounded,S)(S source)
{
    static if(rounded) const r=source.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor);
    else const r=source.checkedQuantityAs!(Length,Metre,long);
    Quantity!(Length,long) value;
    return r.tryValue(value)?cast(ulong)value.canonicalValue:ulong.max;
}
@safe pure nothrow @nogc
ulong baseline(bool rounded,S)(S source)
{
    const r=convertFloatingLong(source,1,1,1,1,rounded,IntegralRoundingMode.floor);
    return r.hasValue?cast(ulong)r.value:ulong.max;
}
extern(C):
pragma(inline,false) ulong r15FloatLong(float value) { return requested!false(value); }
pragma(inline,false) ulong r15BaselineFloatLong(float value) { return baseline!false(value); }
pragma(inline,false) ulong r15DoubleLong(double value) { return requested!false(value); }
pragma(inline,false) ulong r15BaselineDoubleLong(double value) { return baseline!false(value); }
pragma(inline,false) ulong r15DoubleLongFloor(double value) { return requested!true(value); }
pragma(inline,false) ulong r15BaselineDoubleLongFloor(double value) { return baseline!true(value); }
static if(qualifiedReal) pragma(inline,false) ulong r15RealLong(real value) { return requested!false(value); }
static if(qualifiedReal) pragma(inline,false) ulong r15BaselineRealLong(real value) { return baseline!false(value); }
static if(qualifiedReal) pragma(inline,false) ulong r15RealLongFloor(real value) { return requested!true(value); }
static if(qualifiedReal) pragma(inline,false) ulong r15BaselineRealLongFloor(real value) { return baseline!true(value); }
