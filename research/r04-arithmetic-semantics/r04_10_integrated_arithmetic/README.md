# R04.10 — Integrated Quantity arithmetic gate

## Goal

Integrate the previously isolated R04 decisions in one research-local
Quantity-shaped model before modifying production code.

The gate composes:

```text
Spec semantics
    -> ResultSpec
    -> ResultRep
    -> Quantity operation
```

Semantic authorization and representation safety must both succeed.

## Scope

Positive M3 Length slice:

- same-Spec addition;
- same-Spec subtraction;
- Quantity * integral scalar;
- integral scalar * Quantity;
- named exact integral scalar division.

Negative gates:

- same-Dimension non-additive Spec arithmetic;
- cross-Spec arithmetic;
- Class-O integral Rep combinations;
- raw integral Quantity / scalar.

## Semantic model

Length declares:

- closedAdditiveValue;
- scalableValue.

Radius shares LengthDimension and Metre but declares neither.

Addition/subtraction use AddResult/SubResult.

Scalar multiplication and exact division use scalableValue.

## Representation model

Use the already researched type-only traits:

- AddRep;
- SubRep;
- MulRep;
- QuotientRep.

A void result rejects the operation at compile time.

## exactDiv

The integrated prototype keeps only the reachable Class-W states:

- exact;
- inexact;
- divisionByZero.

No overflow state is needed because non-void QuotientRep proves every exact
quotient representable.

## Required gates

- int + uint Length -> long Length;
- uint - uint Length -> long Length, including negative result;
- uint * uint scalar -> ulong Length;
- symmetric scalar multiplication;
- int.min / -1 -> exact long Length;
- 5 / 2 -> inexact, no payload;
- division by zero -> divisionByZero, no payload;
- CTFE;
- @safe pure nothrow @nogc;
- Radius + Radius rejects;
- Length + Radius rejects;
- tested Class-O operations reject;
- raw integral / rejects.

Passing this gate does not itself promote the API. It establishes that the
researched semantic and representation layers compose coherently.


## Observed result

After replacing the integrated probe's initially simplified ResultRep shape
formulas with the already proven R04.2.7 formulas, the complete gate passed in
all four baseline configurations:

- DMD 2.111 debug: pass;
- DMD 2.111 release: pass;
- LDC 1.41 debug: pass;
- LDC 1.41 release: pass.

All runs exited with status 0.

The initial failure was probe-local: its copied MulShape approximation
incorrectly classified uint * uint as Class O. R04.2.7 had already established
uint * uint -> ulong. Reusing the verified formulas removed the discrepancy.

This is also a process lesson: production promotion should reuse one normative
ResultRep implementation rather than duplicate or simplify the formulas across
arithmetic sites.

## Integrated conclusion

The researched layers compose coherently:

```text
Spec declaration
    -> semantic relationship/capability
    -> ResultSpec
    -> representation ResultRep
    -> Quantity result
```

The positive gate confirms:

- mixed integral Rep same-Spec Length addition;
- unsigned subtraction producing a signed widened result;
- overflow-free integral scalar multiplication;
- symmetric scalar multiplication;
- exact integral division including int.min / -1;
- CTFE;
- @safe pure nothrow @nogc.

The negative compile-time gates confirm:

- same Dimension does not authorize Radius arithmetic;
- cross-Spec Length/Radius addition is unavailable;
- tested Class-O integral operations are unavailable;
- Class-O exact division is unavailable;
- raw integral Quantity/scalar division is unavailable.

## Promotion readiness

The first M3 Length arithmetic slice is ready for production implementation,
subject to normal production review and repository gates.

Promote only the evidenced scope:

1. Length declares closed-additive and scalable semantics.
2. AddResult/SubResult provide the semantic query layer.
3. one normative internal integral ResultRep implementation serves all
   arithmetic operators.
4. same-Spec Length + and - use semantic plus representation gates.
5. integral scalar multiplication is symmetric and uses MulRep.
6. integral scalar division has no raw / operator.
7. named exact integral division uses QuotientRep and the three reachable
   states exact, inexact, divisionByZero.

Do not promote cross-Spec arithmetic, derived dimensions, Quantity x Quantity,
rounded division, or general checked Class-O arithmetic as part of this slice.
