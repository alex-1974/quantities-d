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

run_reject() {
    local compiler="$1"
    local version_flag="$2"
    local case_name="$3"
    local compiler_name
    compiler_name="$(basename "$compiler")"
    local log="$OUT/${compiler_name}-${case_name}.log"

    if "$compiler" -c "$SRC" -I"$IMPORT" "$version_flag$case_name" \
        -of=/tmp/quantities-negative.o >"$log" 2>&1; then
        echo "FAIL: $compiler_name accepted $case_name"
        return 1
    fi

    echo "PASS: $compiler_name rejected $case_name"
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
    run_case "$compiler" "$flag" M2NonCanonicalKilometreConstruction "quantity: non-canonical Unit construction requires checkedQuantity, exactQuantity, or roundedQuantity."
    run_case "$compiler" "$flag" M2NonCanonicalInternationalFootExtraction "inUnit: non-canonical Unit extraction requires checkedIn, exactIn, or roundedIn."
    run_case "$compiler" "$flag" M2WrongDimensionConstruction "checkedQuantity: Spec and Unit must have the same Dimension."
    run_reject "$compiler" "$flag" M3NonAdditiveSameSpecAddition
    run_reject "$compiler" "$flag" M3CrossSpecAddition
    run_reject "$compiler" "$flag" M3ClassOAddition
    run_reject "$compiler" "$flag" M3CheckedAddMixed64ClassOM
    run_reject "$compiler" "$flag" M3CheckedAddInvalidSemantics
    run_reject "$compiler" "$flag" M3CheckedSubMixed64ClassOM
    run_reject "$compiler" "$flag" M3CheckedSubInvalidSemantics
    run_reject "$compiler" "$flag" M3RawIntegralDivision
    run_reject "$compiler" "$flag" M3NonScalableMultiplication
    run_reject "$compiler" "$flag" M3NonScalableRightMultiplication
    run_reject "$compiler" "$flag" M3ClassOMultiplication
    run_reject "$compiler" "$flag" M3UnsafeIntFloatScalarMultiplication
    run_reject "$compiler" "$flag" M3UnsafeLongDoubleScalarMultiplication
    run_reject "$compiler" "$flag" M3UnsafeRightLongDoubleScalarMultiplication
    run_reject "$compiler" "$flag" R0416RawIntegralScalarDivision
    run_reject "$compiler" "$flag" R0416UnsafeIntFloatScalarDivision
    run_reject "$compiler" "$flag" R0416UnsafeLongDoubleScalarDivision
    run_reject "$compiler" "$flag" R0416ScalarOverQuantity
    run_reject "$compiler" "$flag" R0416NonScalableScalarDivision
    run_reject "$compiler" "$flag" M3NonScalableExactDivision
    run_reject "$compiler" "$flag" M3ClassOExactDivision
    run_reject "$compiler" "$flag" M3ProductMissingRelation
    run_case "$compiler" "$flag" M3ProductConflictingRelations "conflicting Quantity product semantic relations"
    run_case "$compiler" "$flag" M3ProductWrongResultDimension "Quantity product ResultSpec has the wrong physical Dimension."
    run_reject "$compiler" "$flag" M3QuantityProductMissingRelation
    run_reject "$compiler" "$flag" M3QuantityProductClassO
    run_reject "$compiler" "$flag" M3UnsafeIntFloatQuantityProduct
    run_reject "$compiler" "$flag" M3UnsafeLongDoubleQuantityProduct
    run_reject "$compiler" "$flag" M3QuantityProductCanonicalRescale
    run_case "$compiler" "$flag" M3FloatingQuantityProductCanonicalRescale "quantities-d: nontrivial binary64 product rescale requires runtime represented-source semantics"
    run_reject "$compiler" "$flag" M3ExternalProductMissingRelation
    run_case "$compiler" "$flag" M3ExternalProductWrongResultDimension "external Quantity product ResultSpec has the wrong physical Dimension."
    run_reject "$compiler" "$flag" M3ExternalProductClassO
    run_reject "$compiler" "$flag" M3ExternalProductCanonicalRescale
    run_reject "$compiler" "$flag" M3CheckedMulMissingRelation
    run_reject "$compiler" "$flag" M3CheckedMulMixed64ClassOM
    run_reject "$compiler" "$flag" M3ExternalCheckedMulMissingRelation
    run_reject "$compiler" "$flag" M3QuotientMissingRelation
    run_case "$compiler" "$flag" M3QuotientConflictingRelations "conflicting Quantity quotient semantic relations"
    run_case "$compiler" "$flag" M3QuotientWrongResultDimension "Quantity quotient ResultSpec has the wrong physical Dimension."
    run_reject "$compiler" "$flag" M3QuantityQuotientMissingRelation
    run_reject "$compiler" "$flag" M3QuantityQuotientClassO
    run_reject "$compiler" "$flag" M3QuantityRawIntegralQuotient
    run_reject "$compiler" "$flag" M3UnsafeIntFloatQuantityQuotient
    run_reject "$compiler" "$flag" M3UnsafeLongDoubleQuantityQuotient
    run_case "$compiler" "$flag" M3FloatingQuantityQuotientCanonicalRescale "quantities-d: nontrivial binary64 quotient rescale requires runtime represented-source semantics"
    run_reject "$compiler" "$flag" M3ExternalQuotientMissingRelation
    run_case "$compiler" "$flag" M3ExternalQuotientWrongResultDimension "external Quantity quotient ResultSpec has the wrong physical Dimension."
    run_reject "$compiler" "$flag" M3ExternalQuotientNoFallback
}

if [[ $# -gt 0 ]]; then
    run_compiler "$1"
elif [[ -n "${DC:-}" ]]; then
    run_compiler "$DC"
else
    run_compiler dmd
    run_compiler ldc2
fi
