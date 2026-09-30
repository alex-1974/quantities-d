# Changelog

All notable released changes to `quantities-d` will be documented here.

The project is currently unreleased and in research/architecture phase.

## Unreleased

- Fix binary64 checked/exact conversion range classification: an exact finite
  result outside `[-double.max, double.max]` reports overflow even when IEEE
  nearest-even rounding would return a finite boundary value (#46).

- Initialize repository, package identity, CI, external consumer smoke test,
  architecture boundary, research backlog, and initial design constraints.
