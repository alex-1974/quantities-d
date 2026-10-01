#!/usr/bin/env python3
"""Retain disassembly of callable API probes, not an instruction-count gate."""
import json
import re
import subprocess
import sys

symbols=["r15FloatFloat","r15FloatDouble","r15DoubleDouble",
         "r15BaselineFloatFloat","r15BaselineFloatDouble","r15BaselineDoubleDouble"]
for symbol in symbols:
    text=subprocess.check_output(["objdump","-d","-Mintel",f"--disassemble={symbol}",sys.argv[1]],text=True)
    lines=text.splitlines()
    instructions=[line for line in lines if re.match(r"\s*[0-9a-f]+:\s",line)]
    assert instructions,f"missing codegen symbol {symbol}"
    calls=[line.strip() for line in instructions if re.search(r"\bcall\b",line)]
    print("CODEGEN "+json.dumps({"symbol":symbol,"instructions":len(instructions),"calls":calls}))
    if not symbol.startswith("r15Baseline"):
        print("ASSEMBLY_BEGIN "+symbol)
        print(text)
        print("ASSEMBLY_END "+symbol)
