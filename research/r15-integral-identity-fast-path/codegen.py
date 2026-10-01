#!/usr/bin/env python3
"""Retain disassembly of callable API probes, not an instruction-count gate."""
import json
import re
import subprocess
import sys

symbols=["r15FloatLong","r15DoubleLong","r15DoubleLongFloor",
         "r15BaselineFloatLong","r15BaselineDoubleLong","r15BaselineDoubleLongFloor"]
if sys.argv[2] == "64":
    symbols += ["r15RealLong","r15RealLongFloor","r15BaselineRealLong","r15BaselineRealLongFloor"]
full=subprocess.check_output(["objdump","-d","-Mintel","--no-show-raw-insn",sys.argv[1]],text=True)
functions={}
current=None
for line in full.splitlines():
    match=re.match(r"^[0-9a-f]+ <([^>]+)>:",line)
    if match:
        current=match.group(1)
        functions[current]=[]
    elif current and re.match(r"\s*[0-9a-f]+:\s",line):
        functions[current].append(line)

def reachable(symbol):
    found=set()
    pending=[symbol]
    while pending:
        name=pending.pop()
        if name in found: continue
        found.add(name)
        for line in functions.get(name,[]):
            match=re.search(r"\b(?:call|jmp)\s+[0-9a-f]+ <([^>]+)>",line)
            if match: pending.append(re.sub(r"\+0x[0-9a-f]+$","",match.group(1)))
    return found

for symbol in symbols:
    text=subprocess.check_output(["objdump","-d","-Mintel","--no-show-raw-insn",f"--disassemble={symbol}",sys.argv[1]],text=True)
    instructions=functions.get(symbol,[])
    assert instructions,f"missing codegen symbol {symbol}"
    calls=[line.strip() for line in instructions if re.search(r"\bcall\b",line)]
    targets=reachable(symbol)
    wide=[name for name in sorted(targets) if name.startswith("_D"+str(len("r15_composed_kernel"))+"r15_composed_kernel") or name.startswith("_D"+str(len("r15_floating_integral_kernel"))+"r15_floating_integral_kernel")]
    assert bool(wide)==symbol.startswith("r15Baseline"),(symbol,wide)
    print("CODEGEN "+json.dumps({"symbol":symbol,"instructions":len(instructions),"calls":calls,
        "reachable_functions":len(targets),"wide_kernel_reachable":bool(wide)}))
    if not symbol.startswith("r15Baseline"):
        print("ASSEMBLY_BEGIN "+symbol)
        print(text)
        print("ASSEMBLY_END "+symbol)
