# Implementation

The bootstrap compiler and host tooling will use portable ISO C11. Scaffolding
and experiments may be developed here while global F0 remains open, but the
project must not claim that F1 has started until it is explicitly authorized.

Keep host orchestration separate from pure bounded semantic components. The
latter should expose narrow interfaces suitable for later replacement by
Seki-generated C. See
[`docs/decisions/0005-c11-bootstrap-and-dogfooding.md`](../docs/decisions/0005-c11-bootstrap-and-dogfooding.md).

The `e0/` directory contains disposable closed-subset implementations for the
authorized E0-VS1 experiment. `sekic_e0.c` maps the selected source slice to
SCB-0; `seki_e0_c_backend.c` independently reopens that SCB-0 and maps it through
a minimal restricted-C AST to deterministic C11. Neither defines a frozen
compiler architecture or conformance boundary.
