module r15_identity_codegen;
import quantities.conversion;
import quantities.quantity : Quantity;
import quantities.length : Length,Metre;
import r15_floating_target_kernel : composedFloating;
import r15_rescale_kernel : Status,storedBits;

@safe pure nothrow @nogc
ulong requested(T,S)(S source)
{
    const r=source.checkedQuantityAs!(Length,Metre,T);
    Quantity!(Length,T) value;
    return r.tryValue(value)?storedBits(value.canonicalValue):ulong.max;
}
@safe pure nothrow @nogc
ulong baseline(T,S)(S source)
{
    const r=composedFloating!T(source,1,1,1,1);
    return r.status==Status.nonFinite || r.status==Status.overflow?ulong.max:storedBits(r.value);
}
extern(C):
pragma(inline,false) ulong r15FloatFloat(float value) { return requested!float(value); }
pragma(inline,false) ulong r15FloatDouble(float value) { return requested!double(value); }
pragma(inline,false) ulong r15DoubleDouble(double value) { return requested!double(value); }
pragma(inline,false) ulong r15BaselineFloatFloat(float value) { return baseline!float(value); }
pragma(inline,false) ulong r15BaselineFloatDouble(float value) { return baseline!double(value); }
pragma(inline,false) ulong r15BaselineDoubleDouble(double value) { return baseline!double(value); }
