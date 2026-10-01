# R15 Probe 21 — promotion API readiness

The selected Probe 20 implementation remains a research shadow. Two preparation changes are explicit: export all six TargetRep request names from package quantities, and reject CTFE for every request involving an ordinary floating Source or TargetRep. Integral long/ulong → long retains CTFE. In particular, layout-free real decomposition does not by itself authorize an ordinary-real CTFE exactness claim.

The external-module consumer imports public API names solely through quantities, checks all six free-function/UFCS forms, evaluates integral checks at CTFE and runtime, rejects all six real→long CTFE forms, and verifies real runtime rounding. Target real stays excluded. All Probe 14/15/16/18/19/20 oracles and consumers rerun under this shadow in debug, release and optimized builds on DMD/LDC.

No numerical kernel changes or production promotion. Results pending CI. The durable proposed contract and selective implementation sequence are recorded in the proposed ADR 0012.
