#!/usr/bin/env python3
"""Retain disassembly of callable API probes, not an instruction-count gate."""
import json
import re
import subprocess
import sys

symbols=["r15LongLong","r15UlongLong","r15UlongLongFloor","r15LongFootFloor",
         "r15BaselineLongLong","r15BaselineUlongLong","r15BaselineUlongLongFloor","r15BaselineLongFootFloor"]
full=subprocess.check_output(["objdump","-d","-Mintel","--no-show-raw-insn",sys.argv[1]],text=True)
functions={}
function_addresses={}
symbol_addresses={}
for line in subprocess.check_output(["nm","-n","--defined-only",sys.argv[1]],text=True).splitlines():
    fields=line.split()
    if len(fields)>=3 and re.fullmatch("[0-9a-fA-F]+",fields[0]):
        symbol_addresses[fields[2]]=int(fields[0],16)
current=None
for line in full.splitlines():
    match=re.match(r"^[0-9a-f]+ <([^>]+)>:",line)
    if match:
        current=match.group(1)
        functions[current]=[]
        function_addresses[current]=int(line.split()[0],16)
    elif current and re.match(r"\s*[0-9a-f]+:\s",line):
        functions[current].append(line)

by_address={address:name for name,address in function_addresses.items()}
def resolve(symbol):
    if symbol in functions:return symbol
    return by_address.get(symbol_addresses.get(symbol),symbol)

def reachable(symbol):
    found=set()
    pending=[symbol]
    while pending:
        name=resolve(pending.pop())
        if name in found: continue
        found.add(name)
        for line in functions.get(name,[]):
            match=re.search(r"\b(?:call|jmp)\s+[0-9a-f]+ <([^>]+)>",line)
            if match: pending.append(re.sub(r"\+0x[0-9a-f]+$","",match.group(1)))
    return found

for symbol in symbols:
    canonical=resolve(symbol)
    instructions=functions.get(canonical,[])
    if instructions:
        start=function_addresses[canonical]
        stops=[address for address in function_addresses.values() if address>start]
        args=[f"--start-address={start}"]
        if stops:args.append(f"--stop-address={min(stops)}")
        text=subprocess.check_output(["objdump","-d","-Mintel","--no-show-raw-insn",*args,sys.argv[1]],text=True)
    assert instructions,f"missing codegen symbol {symbol}"
    calls=[line.strip() for line in instructions if re.search(r"\bcall\b",line)]
    targets=reachable(symbol)
    wide=[name for name in sorted(targets) if name.startswith("_D"+str(len("r15_composed_kernel"))+"r15_composed_kernel") or name.startswith("_D"+str(len("r15_floating_integral_kernel"))+"r15_floating_integral_kernel")]
    assert bool(wide)==(symbol.startswith("r15Baseline") or symbol=="r15LongFootFloor"),(symbol,wide)
    print("CODEGEN "+json.dumps({"symbol":symbol,"disassembly_symbol":canonical,"instructions":len(instructions),"calls":calls,
        "reachable_functions":len(targets),"wide_kernel_reachable":bool(wide)}))
    if not symbol.startswith("r15Baseline"):
        print("ASSEMBLY_BEGIN "+symbol)
        print(text)
        print("ASSEMBLY_END "+symbol)
