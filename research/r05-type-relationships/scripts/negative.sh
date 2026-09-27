#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/source/negative.d"

run_negative() {
    local compiler="$1" version="$2"
    echo "=== ${compiler} / ${version} ==="
    if "${compiler}" -version="${version}" -c "${SRC}" -of=/tmp/quantities-r05-negative.o >/tmp/quantities-r05-negative.log 2>&1; then
        echo "ERROR: negative case compiled successfully"
        cat /tmp/quantities-r05-negative.log
        return 1
    fi
    echo "PASS: compilation rejected as required"
}

for compiler in dmd ldc2; do
    run_negative "${compiler}" NegativeWrongDimension
    run_negative "${compiler}" NegativeMissingCanonicalUnit
    run_negative "${compiler}" NegativeMissingDimension
done
