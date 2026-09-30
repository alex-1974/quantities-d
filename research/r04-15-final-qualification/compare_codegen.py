#!/usr/bin/env python3
import re
import subprocess
import sys

obj = sys.argv[1]

pairs = [
    ("raw_add", "quantity_add"),
    ("raw_sub", "quantity_sub"),
    ("raw_scalar_mul", "quantity_scalar_mul"),
    ("raw_product", "quantity_product"),
    ("raw_quotient", "quantity_quotient"),
]

text = subprocess.check_output(
    ["objdump", "-d", "--no-show-raw-insn", obj],
    text=True,
)

header = re.compile(r"^[0-9a-f]+ <([^>]+)>:$")
instruction = re.compile(r"^\s*[0-9a-f]+:\s*(.*)$")

bodies = {}
current = None

for line in text.splitlines():
    m = header.match(line)
    if m:
        current = m.group(1)
        bodies[current] = []
        continue

    if current is None:
        continue

    m = instruction.match(line)
    if m:
        body = re.sub(r"\s+", " ", m.group(1).strip())
        if body:
            bodies[current].append(body)

failed = False

for raw, wrapped in pairs:
    if raw not in bodies or wrapped not in bodies:
        print(f"ERROR missing symbol: {raw} or {wrapped}")
        failed = True
        continue

    print(f"{raw}:      {' | '.join(bodies[raw])}")
    print(f"{wrapped}: {' | '.join(bodies[wrapped])}")

    if bodies[raw] != bodies[wrapped]:
        print(f"MISMATCH {raw} != {wrapped}")
        failed = True
    else:
        print(f"PASS {raw} == {wrapped}")

if failed:
    sys.exit(1)

print("R04.15 Probe 9 PASS: Quantity native/identity codegen matches scalar bodies")
