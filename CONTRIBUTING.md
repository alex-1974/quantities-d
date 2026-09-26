# Contributing

`quantities-d` is currently in research/architecture phase. Do not expand the
public API merely because a units framework can express something.

Before proposing a public declaration, establish:

1. a concrete reusable consumer requirement;
2. the semantic distinction being protected;
3. conversion/loss behavior;
4. `@safe`, `pure`, `nothrow`, `@nogc`, and CTFE expectations where applicable;
5. DMD 2.111 and LDC 1.41 behavior;
6. storage/runtime/compile-time cost where the abstraction claims zero overhead;
7. compile-negative tests when invalid source is part of the contract.

Daily integration targets `develop`. Use focused short-lived branches; longer
`research/*` branches are appropriate only while evidence gathering genuinely
requires them. `main` is reserved for release-quality states.

Baseline verification:

```bash
dub test --compiler=dmd --force
dub test --compiler=ldc2 --force
dub build --build=release --compiler=dmd --force
dub build --build=release --compiler=ldc2 --force

cd tests/consumer
dub run --compiler=dmd --force
dub run --compiler=ldc2 --force
```
