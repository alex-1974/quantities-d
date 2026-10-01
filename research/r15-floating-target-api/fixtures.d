module r15_float_api_fixtures;
import quantities.length : Metre, Length, InternationalFoot;
import quantities.unit : DerivedUnit;
import quantities.ratio : ExactRatio;
alias WideFrom = DerivedUnit!(Metre.Dimension,ExactRatio!(long.max,long.max-18));
alias WideTo = DerivedUnit!(Metre.Dimension,ExactRatio!(long.max-20,long.max-6));
alias NegativeUnit = DerivedUnit!(Metre.Dimension,ExactRatio!(long.min,long.max));
alias DirectRoundingUnit = DerivedUnit!(Metre.Dimension,
    ExactRatio!((1L<<60)+(1L<<36)+1,1L<<60));
alias NearMaxUnit = DerivedUnit!(Metre.Dimension,ExactRatio!((1L<<62)+1,1L<<62));
struct WideSpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=WideTo; }
struct FootSpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=InternationalFoot; }
struct NegativeSpec { alias Dimension=Metre.Dimension; alias CanonicalUnit=NegativeUnit; }
