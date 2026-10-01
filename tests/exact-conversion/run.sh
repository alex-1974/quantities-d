#!/usr/bin/env bash
set -euo pipefail
compiler=$1
research=$2
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
python3 tests/exact-conversion/prepare.py "$research" "$build"
for configuration in debug release optimized; do
    flags=()
    if [[ $configuration == release ]]; then flags=(-release); fi
    if [[ $configuration == optimized ]]; then
        if [[ $compiler == *ldc* ]]; then flags=(-O3 -release -boundscheck=on); else flags=(-O -release -boundscheck=on); fi
    fi
    for probe in r15-composed-unit-rescale r15-floating-integral r15-floating-source-integral; do
        "$compiler" "${flags[@]}" -Isource "$build/$probe/runner.d" source/quantities/exact_conversion.d -of="$build/runner"
        python3 "$build/$probe/oracle.py" "$build/runner"
    done
    "$compiler" "${flags[@]}" -Isource tests/exact-conversion/source-floating.d source/quantities/exact_conversion.d -of="$build/source-floating"
    python3 tests/exact-conversion/source-floating.py "$build/source-floating" "$research"
    echo "PASS $configuration"
done
# An ordinary external module cannot reach package-only entry points or Wide.
cat > "$build/external.d" <<'D'
module external;
import quantities.exact_conversion;
import quantities.conversion : RoundingMode;
static assert(!__traits(compiles, { Wide workspace; }));
static assert(!__traits(compiles, convertFloating!float(1L,1,1,1,1)));
static assert(!__traits(compiles, convertIntegral(1L,1,1,1,1,false,RoundingMode.towardZero)));
void main() {}
D
"$compiler" -Isource "$build/external.d" -of="$build/external"
