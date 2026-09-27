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
