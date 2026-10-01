module conversion_as_negative;
import quantities;

struct BrokenSpec {}
struct BrokenUnit {}
struct OtherTag {}
alias WrongUnit = DerivedUnit!(BaseDimension!OtherTag, ExactRatio!(1,1));
alias ZeroUnit = DerivedUnit!(LengthDimension, ExactRatio!(0,1));
struct FractionalUnit
{
    alias Dimension = LengthDimension;
    struct Scale { enum numerator = 1.5; enum denominator = 1.0; }
}
struct BadDenominator
{
    alias Dimension = LengthDimension;
    struct Scale { enum long numerator = 1; enum long denominator = 0; }
}

version (IntSource) auto bad = 1.checkedQuantityAs!(Length,Metre,long);
version (BoolSource) auto bad = true.exactQuantityAs!(Length,Metre,double);
version (StringSource) auto bad = "1".checkedQuantityAs!(Length,Metre,float);
version (RealTarget) auto bad = 1L.checkedQuantityAs!(Length,Metre,real);
version (UlongTarget) auto bad = 1L.checkedQuantityAs!(Length,Metre,ulong);
version (FloatingRounded) auto bad = 1L.roundedQuantityAs!(Length,Metre,float,RoundingMode.floor);
version (InvalidMode) auto bad = 1L.roundedQuantityAs!(Length,Metre,long,cast(RoundingMode)99);
version (OverrideSource) auto bad = 1UL.checkedQuantityAs!(Length,Metre,long,ulong);
version (OverrideExtraction) auto bad = 1UL.quantity!(Length,Metre).checkedInAs!(Metre,long,Length);
version (DimensionMismatch) auto bad = 1L.checkedQuantityAs!(Length,WrongUnit,long);
version (InvalidSpec) auto bad = 1L.checkedQuantityAs!(BrokenSpec,Metre,long);
version (InvalidUnit) auto bad = 1L.checkedQuantityAs!(Length,BrokenUnit,long);
version (ZeroScale) auto bad = 1L.checkedQuantityAs!(Length,ZeroUnit,long);
version (FractionalScale) auto bad = 1L.checkedQuantityAs!(Length,FractionalUnit,long);
version (InvalidDenominator) auto bad = 1L.checkedQuantityAs!(Length,BadDenominator,long);
version (CtfeFloatSource) enum bad = 1.0F.checkedQuantityAs!(Length,Metre,long);
version (CtfeDoubleSource) enum bad = 1.0.exactQuantityAs!(Length,Metre,long);
version (CtfeRealSource) enum bad = 1.0L.roundedQuantityAs!(Length,Metre,long,RoundingMode.floor);
version (CtfeFloatingTarget) enum bad = 1L.checkedQuantityAs!(Length,Metre,double);
version (CtfeFloatIdentity) enum bad = 1.0F.checkedQuantityAs!(Length,Metre,float);
version (CtfeDoubleIdentity) enum bad = 1.0.exactQuantityAs!(Length,Metre,double);
version (CtfeNonFinite) enum bad = double.nan.checkedQuantityAs!(Length,Metre,long);
version (CtfeExtraction)
{
    enum q = 1.0L.quantity!(Length,Metre);
    enum bad = q.checkedInAs!(Metre,long);
}
