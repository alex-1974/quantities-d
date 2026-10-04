#!/usr/bin/env python3
from __future__ import annotations

import statistics
import subprocess
import sys
import time

exe = sys.argv[1]
iterations = int(sys.argv[2]) if len(sys.argv) > 2 else 8000000
repeats = int(sys.argv[3]) if len(sys.argv) > 3 else 7
seed = 0x150012

groups = [
    ("long identity", ["ref-long-id", "kernel-long-id", "api-long-id"]),
    ("quarter nonidentity", ["kernel-quarter", "api-quarter"]),
    ("double to float identity", ["kernel-double-float", "api-double-float"]),
]

results = {}

for title, modes in groups:
    print("##", title)
    for mode in modes:
        subprocess.run(
            [exe, mode, str(max(1, iterations // 8)), str(seed)],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        samples = []
        checksums = set()
        for _ in range(repeats):
            start = time.perf_counter_ns()
            cp = subprocess.run(
                [exe, mode, str(iterations), str(seed)],
                check=True,
                text=True,
                capture_output=True,
            )
            elapsed = time.perf_counter_ns() - start
            samples.append(elapsed / iterations)
            checksums.add(cp.stdout.strip())
        assert len(checksums) == 1, (mode, checksums)
        median = statistics.median(samples)
        results[mode] = median
        print(
            f"{mode:22s} median={median:9.3f} ns/op "
            f"min={min(samples):9.3f} max={max(samples):9.3f} "
            f"checksum={next(iter(checksums))}"
        )
    baseline = results[modes[0]]
    for mode in modes[1:]:
        print(f"ratio {mode}/{modes[0]} = {results[mode] / baseline:.4f}")
    print()
