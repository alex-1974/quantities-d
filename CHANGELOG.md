# Changelog

All notable released changes to `quantities-d` will be documented here.

The project is currently unreleased and in research/architecture phase.

## Unreleased

- Add six explicit target-Rep conversion requests: checked/exact/rounded
  Quantity construction and Unit extraction (`*As`). Source Rep is deduced;
  long/ulong/float/double/qualified real convert to long/float/double, with
  integral rounding for long targets. Preserve represented-source exactness,
  range-before-rounding, and the existing result carriers. Floating requests
  require runtime; long/ulong to long support CTFE. Legacy inferred APIs remain
  unchanged (#42; proposed ADR 0012).

- Prevent contradictory conversion-result states through external aggregate
  construction. Checked/exact carriers now use a private state discriminant;
  public accessors and valid default states are unchanged. The private carrier
  layout changes, so consumers must rebuild (#48).

- Fix binary64 checked/exact conversion range classification: an exact finite
  result outside `[-double.max, double.max]` reports overflow even when IEEE
  nearest-even rounding would return a finite boundary value (#46).

- Initialize repository, package identity, CI, external consumer smoke test,
  architecture boundary, research backlog, and initial design constraints.

