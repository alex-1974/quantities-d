#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT/source/r13_core.d"
CONSUMER="$ROOT/source/raw_consumer.d"
OUT="$ROOT/results"
mkdir -p "$OUT"

compile_ok() {
    local compiler="$1"
    local flag="$2"
    local case_name="$3"
    local log="$OUT/${compiler}-${case_name}.log"

    if "$compiler" "$CORE" "$CONSUMER" "$flag$case_name" -of=/tmp/quantities-r13-module-boundary >"$log" 2>&1; then
        echo "PASS: $compiler accepted $case_name"
    else
        echo "FAIL: $compiler rejected expected-positive $case_name"
        cat "$log"
        return 1
    fi
}

compile_reject() {
    local compiler="$1"
    local flag="$2"
    local case_name="$3"
    local needle="$4"
    local log="$OUT/${compiler}-${case_name}.log"

    if "$compiler" "$CORE" "$CONSUMER" "$flag$case_name" -of=/tmp/quantities-r13-module-boundary >"$log" 2>&1; then
        echo "FAIL: $compiler accepted $case_name"
        return 1
    fi

    if grep -Fq "$needle" "$log"; then
        echo "PASS: $compiler rejected $case_name at module boundary"
    else
        echo "FAIL: $compiler rejected $case_name, but expected boundary evidence was not found"
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

    compile_ok "$c" "$flag" ValidPublicConstruction
    compile_reject "$c" "$flag" RawConstructor "private"
    compile_reject "$c" "$flag" RawField "private"
done
