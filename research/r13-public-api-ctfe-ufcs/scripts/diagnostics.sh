#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/source/negative.d"
OUT="$ROOT/results"
mkdir -p "$OUT"

run_case() {
    local compiler="$1"
    local version_flag="$2"
    local case_name="$3"
    local needle="$4"
    local log="$OUT/${compiler}-${case_name}.log"

    if "$compiler" -c "$SRC" "$version_flag$case_name" -of=/tmp/quantities-r13-negative.o >"$log" 2>&1; then
        echo "FAIL: $compiler accepted $case_name"
        return 1
    fi

    if grep -Fq "$needle" "$log"; then
        echo "PASS: $compiler rejected $case_name with boundary diagnostic"
    else
        echo "FAIL: $compiler rejected $case_name, but expected diagnostic was not found"
        cat "$log"
        return 1
    fi
}

for c in dmd ldc2; do
    if [[ "$c" == "dmd" ]]; then
        flag="-version="
    else
        flag="-d-version="
    fi

    run_case "$c" "$flag" WrongDimension "quantity: Spec and Unit must have the same Dimension."
    run_case "$c" "$flag" BrokenSpecCase "quantity: Spec must define Dimension and a valid CanonicalUnit."
    run_case "$c" "$flag" BrokenUnitCase "quantity: Unit must define Dimension and Scale."
done
