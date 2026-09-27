#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/source/negative.d"
OUT="${ROOT}/results"
mkdir -p "${OUT}"

cases=(
    MissingSpecDimension
    MissingCanonicalUnit
    WrongCanonicalDimension
    MissingUnitDimension
    MissingUnitScale
)

for compiler in dmd ldc2; do
    for case_name in "${cases[@]}"; do
        log="${OUT}/${compiler}-${case_name}.log"
        echo "=== ${compiler} / ${case_name} ==="
        if "${compiler}" -version="${case_name}" -c "${SRC}"             -of=/tmp/quantities-r11-negative.o >"${log}" 2>&1; then
            echo "ERROR: invalid declaration compiled"
            exit 1
        fi
        if grep -Fq "Quantity Spec must define Dimension and a valid CanonicalUnit with the same Dimension." "${log}"; then
            echo "PASS: rejected with boundary diagnostic"
        else
            echo "FAIL: rejected, but expected boundary diagnostic not found"
            cat "${log}"
            exit 1
        fi
    done
done

echo
echo "Diagnostic logs: ${OUT}"
