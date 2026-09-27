#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/tests/negative/negative.d"
IMPORT="$ROOT/source"
OUT="$ROOT/tests/negative/results"
mkdir -p "$OUT"

run_case() {
    local compiler="$1"
    local version_flag="$2"
    local case_name="$3"
    local needle="$4"
    local compiler_name
    compiler_name="$(basename "$compiler")"
    local log="$OUT/${compiler_name}-${case_name}.log"

    if "$compiler" -c "$SRC" -I"$IMPORT" "$version_flag$case_name" \
        -of=/tmp/quantities-negative.o >"$log" 2>&1; then
        echo "FAIL: $compiler_name accepted $case_name"
        return 1
    fi

    if grep -Fq "$needle" "$log"; then
        echo "PASS: $compiler_name rejected $case_name with boundary diagnostic"
    else
        echo "FAIL: $compiler_name rejected $case_name, but expected diagnostic was not found"
        cat "$log"
        return 1
    fi
}

run_compiler() {
    local compiler="$1"
    local compiler_name
    compiler_name="$(basename "$compiler")"
    local flag

    case "$compiler_name" in
        dmd)
            flag="-version="
            ;;
        ldc2)
            flag="-d-version="
            ;;
        *)
            echo "FAIL: unsupported compiler for negative tests: $compiler"
            return 1
            ;;
    esac

    run_case "$compiler" "$flag" WrongDimension "quantity: Spec and Unit must have the same Dimension."
    run_case "$compiler" "$flag" BrokenSpecCase "quantity: Spec must define Dimension and a valid CanonicalUnit."
    run_case "$compiler" "$flag" BrokenUnitCase "quantity: Unit must define Dimension and a valid exact Scale."
    run_case "$compiler" "$flag" NonCanonicalConstruction "quantity: non-canonical Unit construction requires checkedQuantity, exactQuantity, or roundedQuantity."
    run_case "$compiler" "$flag" NonCanonicalExtraction "inUnit: non-canonical Unit extraction requires checkedIn, exactIn, or roundedIn."
    run_case "$compiler" "$flag" CheckedWrongDimension "checkedQuantity: Spec and Unit must have the same Dimension."
    run_case "$compiler" "$flag" CheckedBrokenSpec "checkedQuantity: Spec must define Dimension and a valid CanonicalUnit."
    run_case "$compiler" "$flag" CheckedBrokenUnit "checkedQuantity: Unit must define Dimension and a valid exact Scale."
    run_case "$compiler" "$flag" CheckedExtractionWrongDimension "checkedIn: Quantity Spec and Unit must have the same Dimension."
}

if [[ $# -gt 0 ]]; then
    run_compiler "$1"
elif [[ -n "${DC:-}" ]]; then
    run_compiler "$DC"
else
    run_compiler dmd
    run_compiler ldc2
fi
