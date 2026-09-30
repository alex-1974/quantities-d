#!/usr/bin/env python3
import statistics
import subprocess
import sys
import time

compiler = sys.argv[1]
kind = sys.argv[2]
source = sys.argv[3]
output = sys.argv[4]
rounds = int(sys.argv[5])

if kind == "dmd":
    command = [
        compiler, "-O", "-release", "-inline", "-boundscheck=off",
        "-Isource", "-i", "-c", source, "-of=" + output,
    ]
elif kind == "ldc":
    command = [
        compiler, "-O3", "-release", "-boundscheck=off",
        "-Isource", "-i", "-c", source, "-of=" + output,
    ]
else:
    raise SystemExit(f"unknown compiler kind: {kind}")

times = []

# Warm-up.
subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

for _ in range(rounds):
    start = time.perf_counter_ns()
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    end = time.perf_counter_ns()
    times.append((end - start) / 1_000_000.0)

print("command:", " ".join(command))
print("rounds:", rounds)
print("min_ms:", f"{min(times):.3f}")
print("median_ms:", f"{statistics.median(times):.3f}")
print("max_ms:", f"{max(times):.3f}")
