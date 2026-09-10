# Implementation

The bootstrap compiler and host tooling will use portable ISO C11. Scaffolding
and experiments may be developed here while global F0 remains open, but the
project must not claim that F1 has started until it is explicitly authorized.

Keep host orchestration separate from pure bounded semantic components. The
latter should expose narrow interfaces suitable for later replacement by
Seki-generated C. See
[`docs/decisions/0005-c11-bootstrap-and-dogfooding.md`](../docs/decisions/0005-c11-bootstrap-and-dogfooding.md).
