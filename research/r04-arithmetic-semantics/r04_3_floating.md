# R04.3 — Floating arithmetic probe

## Purpose

Evaluate whether ordinary IEEE floating arithmetic is a suitable implementation
and semantic basis for same-Spec and scalar Quantity arithmetic.

This is separate from integral arithmetic.

## Probe matrix

Representations:

- float + float
- float + double
- double + float
- double + double

Operations:

- same-Spec addition/subtraction;
- Quantity × scalar and scalar × Quantity;
- Quantity / scalar.

Values:

- ordinary finite values;
- +0 and -0;
- +infinity and -infinity;
- NaN;
- very large finite values leading to infinity;
- very small/subnormal values;
- division by +0 and -0.

Record:

- result Rep;
- result bits where signed zero matters;
- finite/non-finite classification;
- DMD 2.111 versus LDC 1.41;
- debug versus release where relevant;
- CTFE support and agreement;
- @safe pure nothrow @nogc viability.

## Semantic question

IEEE-754 non-finite results are not automatically errors. Unlike checked Unit
conversion, arithmetic may legitimately propagate infinity or NaN if the Rep is
floating.

R04.3 must determine whether quantities-d should:

A. transparently preserve normal floating semantics;
B. reject non-finite arithmetic results;
C. provide ordinary operators plus separately checked arithmetic.

Do not import the M1 ConversionStatus contract automatically: conversion status
describes a boundary conversion outcome, not general arithmetic state.


## Observed runtime matrix — 2026-09-27

The probe was run with DMD 2.111 and LDC 1.41 in debug and release modes.

Stable observations across the tested configurations:

- float + float -> float;
- float + double and double + float -> double;
- double + double -> double;
- +0 + -0 -> +0;
- -0 + -0 -> -0;
- finite / +0 -> +infinity for positive finite input;
- finite / -0 -> -infinity for positive finite input;
- float.max * 2f -> +infinity;
- double.max * 2.0 -> +infinity at runtime;
- the tested half-min-normal values remain subnormal rather than flushing to zero;
- explicit NaN operands propagate as NaN in the tested addition/multiplication cases.

These observations support ordinary IEEE floating arithmetic as a plausible basis
for Quantity runtime arithmetic.

### Important exception: infinity cancellation

The expression `+infinity + -infinity` was not stable across all builds:

- DMD debug: NaN;
- DMD release: observed +0;
- LDC debug: NaN;
- LDC release: NaN.

The NaN sign/payload also differed between some configurations.

Therefore quantities-d must not promise a particular NaN bit pattern. More
importantly, the DMD-release +0 result must be isolated before accepting a
general claim that raw compiler floating arithmetic preserves IEEE exceptional
semantics under all supported build modes.

### CTFE

The initial CTFE probe established that `double.max * 2.0` may remain an
extended-precision finite value at CTFE rather than quantizing immediately to
binary64 infinity.

Therefore a public arithmetic contract must not require bit-identical
intermediate behavior between runtime binary32/binary64 arithmetic and D CTFE.

## Provisional direction

Candidate A — transparently preserve normal floating arithmetic — remains the
preferred minimal policy for ordinary finite runtime arithmetic.

It is not yet promoted because:

1. exceptional expressions need an isolated optimization probe;
2. NaN payload/sign must not be API semantics;
3. runtime/CTFE quantization differences must be documented;
4. attributes and Quantity-wrapper code generation still need verification.

Do not add arithmetic status wrappers merely because NaN or infinity can occur.
That would replace ordinary floating semantics with a new quantities-specific
numerical model without consumer evidence.
