"""Adapt pinned research protocols to the package-only production kernel.

The independent Fraction oracles are copied unchanged except removal of the
research width diagnostic. No research D kernel is compiled into the executables.
"""
from pathlib import Path
import sys

research, output = map(Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=True)
for name in ('r15-exact-unit-rescale', 'r15-composed-unit-rescale',
             'r15-floating-integral', 'r15-floating-source-integral'):
    dest = output / name
    dest.mkdir(exist_ok=True)
    oracle = (research / name / 'oracle.py').read_text()
    if name == 'r15-composed-unit-rescale':
        oracle = oracle.replace(' {nb} {db}', '')
        oracle = '\n'.join(line for line in oracle.splitlines()
                           if 'assert wanted[0].split()[-2:]' not in line) + '\n'
    (dest / 'oracle.py').write_text(oracle)
    if name == 'r15-exact-unit-rescale':
        continue
    runner = (research / name / 'runner.d').read_text()
    runner = runner.replace(runner.splitlines()[0], 'module quantities.verification;')
    import re
    runner = re.sub(r'import r15_\w+\s*(?::[^;]+)?;', '', runner)
    runner = runner.replace('module quantities.verification;',
                            'module quantities.verification;\nimport quantities.exact_conversion;')
    runner = runner.replace('convertFloatingLong', 'convertIntegral')
    # The production source adapter additionally accepts long and ulong.
    runner = re.sub(r'static assert\(!__traits\(compiles, convertIntegral\((?:1L|ulong.max),.*?\)\);', '', runner, flags=re.S)
    runner = runner.replace('    int nb,db;\n    composedWidths(sig,fn,fd,tn,td,nb,db);\n', '')
    runner = runner.replace(',nb," ",db', '')
    runner = runner.replace('" - "', '" -"')
    if name == 'r15-floating-integral':
        runner = runner.replace('const r = convertComposedLong', 'auto r = convertComposedLong')
        marker = '        if (r.hasValue) writeln'
        adapter = """        // For source-representable exponent-zero tuples, exercise the real
        // long/ulong adapter while preserving the independent oracle protocol.
        const sig = f[2].to!ulong;
        if (f[3].to!int == 0)
        {
            if (f[4] != "1")
                r = convertIntegral(sig, f[5].to!long, f[6].to!long,
                    f[7].to!long, f[8].to!long, f[0] == "R",
                    cast(IntegralRoundingMode)f[1].to!int);
            else if (sig <= (1UL << 63))
            {
                const value = sig == (1UL << 63) ? long.min : -cast(long)sig;
                r = convertIntegral(value, f[5].to!long, f[6].to!long,
                    f[7].to!long, f[8].to!long, f[0] == "R",
                    cast(IntegralRoundingMode)f[1].to!int);
            }
        }
"""
        runner = runner.replace(marker, adapter + marker)
    (dest / 'runner.d').write_text(runner)
