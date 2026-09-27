#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for compiler in dmd ldc2; do
    echo "=== $compiler ==="
    dub test --compiler="$compiler" --force
done
