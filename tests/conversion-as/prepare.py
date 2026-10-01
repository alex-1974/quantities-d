"""Adapt pinned R15 public API protocols; compile only production D modules."""
from pathlib import Path
import re
import sys
research, output = map(Path,sys.argv[1:])
output.mkdir(parents=True,exist_ok=True)
names=('r15-exact-unit-rescale','r15-floating-source-integral','r15-mixed-api',
       'r15-floating-target-api','r15-integral-source-api')
mapping={'r15_api_consumer':'conversion_as_contract','r15_integral_source_consumer':'conversion_as_integral',
         'r15_float_api_consumer':'conversion_as_floating','r15_integral_source_fixtures':'conversion_as_integral_fixtures',
         'r15_float_api_fixtures':'conversion_as_float_fixtures',
         'r15_rescale_kernel':'conversion_as_bits','r15_floating_integral_kernel':'conversion_as_bits'}
for name in names:
    dest=output/name
    dest.mkdir(exist_ok=True)
    (dest/'oracle.py').write_text((research/name/'oracle.py').read_text())
    if name not in names[-3:]: continue
    s=(research/name/'runner.d').read_text()
    s=s.replace(s.splitlines()[0],'module conversion_as_runner;\nimport quantities;')
    s=re.sub(r'import quantities(?:\.\w+)?\s*(?::[^;]+)?;', '',s)
    s=s.replace('module conversion_as_runner;', 'module conversion_as_runner;\nimport quantities;')
    for a,b in mapping.items():s=s.replace(a,b)
    (dest/'runner.d').write_text(s)
