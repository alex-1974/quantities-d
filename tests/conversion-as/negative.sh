#!/usr/bin/env bash
set -euo pipefail
compiler=$1
case $(basename "$compiler") in
    dmd) flag=-version= ;;
    ldc2) flag=-d-version= ;;
    *) echo "Unsupported compiler: $compiler"; exit 1 ;;
esac
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
# Compile a positive control first so a broken import cannot make the gate pass.
printf 'module positive; import quantities; enum r=1L.checkedQuantityAs!(Length,Metre,long); static assert(r.hasValue);' > "$build/positive.d"
"$compiler" -c -Isource "$build/positive.d" -of="$build/positive.o"
for probe in IntSource BoolSource StringSource RealTarget UlongTarget FloatingRounded InvalidMode \
    OverrideSource OverrideExtraction DimensionMismatch InvalidSpec InvalidUnit ZeroScale \
    FractionalScale InvalidDenominator CtfeFloatSource CtfeDoubleSource CtfeRealSource \
    CtfeFloatingTarget CtfeFloatIdentity CtfeDoubleIdentity CtfeNonFinite CtfeExtraction; do
    if "$compiler" -c -Isource "$flag$probe" tests/conversion-as/negative.d -of="$build/negative.o" > "$build/log" 2>&1; then
        echo "FAIL accepted $probe"; exit 1
    fi
    echo "PASS rejected $probe"
done
