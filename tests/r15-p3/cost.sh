#!/usr/bin/env bash
set -euo pipefail

compiler=$1
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

case "$(basename "$compiler")" in
  dmd)
    opt=(-O -release -boundscheck=on)
    ;;
  ldc2)
    opt=(-O3 -release -boundscheck=on)
    ;;
  *)
    echo "unsupported compiler: $compiler" >&2
    exit 2
    ;;
esac

measure() {
  local label=$1
  local source=$2
  local object=$3
  local timefile=$4
  /usr/bin/time -f 'elapsed_s=%e user_s=%U sys_s=%S max_rss_kb=%M' -o "$timefile" \
    "$compiler" "${opt[@]}" -Isource -c "$source" -of="$object"
  echo "$label $(cat "$timefile") object_bytes=$(stat -c%s "$object")"
}

echo "=== compiler ==="
"$compiler" --version
echo "=== host ==="
uname -a
lscpu | sed -n '1,28p'

# Warm compiler/toolchain caches once; do not count this run.
"$compiler" "${opt[@]}" -Isource -c tests/r15-p3/cost_minimal.d -of="$build/warm.o"

echo "=== compile cost ==="
for i in 1 2 3 4 5
do
  measure "minimal[$i]" tests/r15-p3/cost_minimal.d "$build/minimal-$i.o" "$build/minimal-$i.time"
  measure "matrix[$i]" tests/consumer/source/conversion_as_contract.d "$build/matrix-$i.o" "$build/matrix-$i.time"
done
