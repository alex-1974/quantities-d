#!/usr/bin/env bash
set -euo pipefail

compiler=${1:-dmd}
iterations=${P3_STABLE_ITERATIONS:-100000}
repeats=${P3_STABLE_REPEATS:-15}
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

echo "=== repository ==="
git rev-parse HEAD
git status --short --branch
echo "=== compiler ==="
"$compiler" --version
echo "=== host ==="
uname -a
lscpu | sed -n '1,32p'
if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-info 2>/dev/null || true
fi

"$compiler" "${opt[@]}" -Isource \
  tests/r15-p3/bench.d source/quantities/*.d \
  -of="$build/bench"

echo "=== stable nonidentity quarter ==="
python3 - "$build/bench" "$iterations" "$repeats" <<'PY'
import statistics, subprocess, sys, time
exe=sys.argv[1]; iterations=int(sys.argv[2]); repeats=int(sys.argv[3]); seed=0x150012
modes=['kernel-quarter','api-quarter']
results={m:[] for m in modes}
checksums={m:set() for m in modes}
for _ in range(repeats):
    for mode in modes:
        start=time.perf_counter_ns()
        cp=subprocess.run([exe,mode,str(iterations),str(seed)],check=True,text=True,capture_output=True)
        elapsed=time.perf_counter_ns()-start
        results[mode].append(elapsed/iterations)
        checksums[mode].add(cp.stdout.strip())
for mode in modes:
    xs=results[mode]
    assert len(checksums[mode])==1,(mode,checksums[mode])
    print(f'{mode:16s} median={statistics.median(xs):.3f} ns/op min={min(xs):.3f} max={max(xs):.3f} stdev={statistics.pstdev(xs):.3f}')
ratios=[a/b for a,b in zip(results['api-quarter'],results['kernel-quarter'])]
print(f'paired api/kernel median={statistics.median(ratios):.5f} min={min(ratios):.5f} max={max(ratios):.5f} stdev={statistics.pstdev(ratios):.5f}')
PY
