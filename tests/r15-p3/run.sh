#!/usr/bin/env bash
set -euo pipefail

compiler=$1
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

case "$(basename "$compiler")" in
  dmd)
    opt=(-O -release -inline -boundscheck=on)
    ;;
  ldc2)
    opt=(-O3 -release -boundscheck=on)
    ;;
  *)
    echo "unsupported compiler: $compiler" >&2
    exit 2
    ;;
esac

echo "=== compiler ==="
"$compiler" --version
echo "=== host ==="
uname -a
lscpu | sed -n '1,28p'

echo "=== build benchmark ==="
"$compiler" "${opt[@]}" -Isource \
  tests/r15-p3/bench.d source/quantities/*.d \
  -of="$build/bench"

echo "benchmark executable bytes: $(stat -c%s "$build/bench")"
python3 tests/r15-p3/benchmark.py "$build/bench" "${P3_ITERATIONS:-8000000}" "${P3_REPEATS:-7}"

echo "=== build codegen probes ==="
"$compiler" "${opt[@]}" -c -Isource \
  tests/r15-p3/codegen.d source/quantities/*.d \
  -of="$build/codegen.o"

echo "codegen object bytes: $(stat -c%s "$build/codegen.o")"

for symbol in \
  p3_codegen_ref_long_identity \
  p3_codegen_kernel_long_identity \
  p3_codegen_api_long_identity \
  p3_codegen_kernel_quarter \
  p3_codegen_api_quarter \
  p3_codegen_kernel_double_to_float \
  p3_codegen_api_double_to_float
do
  echo "=== $symbol ==="
  objdump -drwC --disassemble="$symbol" "$build/codegen.o" || true
done
