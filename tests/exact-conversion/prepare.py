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
    (dest / 'runner.d').write_text(runner)
