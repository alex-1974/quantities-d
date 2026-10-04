module conversion_as_integral_fixtures;
import quantities;



alias HalfUnit=DerivedUnit!(Metre.Dimension,ExactRatio!(1,2));
alias QuarterUnit=DerivedUnit!(Metre.Dimension,ExactRatio!(1,4));
alias DoubleUnit=DerivedUnit!(Metre.Dimension,ExactRatio!(2,1));
alias HugeNegativeUnit=DerivedUnit!(Metre.Dimension,ExactRatio!(long.min,1));
alias TinyUnit=DerivedUnit!(Metre.Dimension,ExactRatio!(1,long.max));
enum a=1L<<62;
alias FromBoundary=DerivedUnit!(Metre.Dimension,ExactRatio!(a-1,a));
alias CanonBoundary=DerivedUnit!(Metre.Dimension,ExactRatio!(a,a+1));
struct BoundarySpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=CanonBoundary; }
struct TinySpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=TinyUnit; }
