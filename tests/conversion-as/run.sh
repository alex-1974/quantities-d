#!/usr/bin/env bash
set -euo pipefail
compiler=$1
research=$2
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
python3 tests/conversion-as/prepare.py "$research" "$build"
for configuration in debug release optimized; do
    flags=()
    if [[ $configuration == release ]]; then flags=(-release); fi
    if [[ $configuration == optimized ]]; then
        if [[ $compiler == *ldc* ]]; then flags=(-O3 -release -boundscheck=on); else flags=(-O -release -boundscheck=on); fi
    fi
    for probe in r15-mixed-api r15-floating-target-api r15-integral-source-api; do
        "$compiler" "${flags[@]}" -Isource -Itests/consumer/source "$build/$probe/runner.d" \
            tests/consumer/source/conversion_as*.d source/quantities/*.d -of="$build/runner"
        python3 "$build/$probe/oracle.py" "$build/runner"
    done
    echo "PASS public API $configuration"
done
