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

The `alpha/` directory contains the provisional `sekic` CLI. Revision
`0.0.0-alpha.2` wraps the immutable E0 frontend and backend behind the narrow
API in `alpha/e0_adapter.h`, so `check`, `build`, and `inspect` run in one process
while the closed E0 sources and artifacts remain byte-for-byte regression
oracles. This is the first A0-02 integration increment, not its exit: the adapter
still recognizes the E0 program shape and must be replaced by a declaration- and
expression-driven compiler core.

`alpha/seki_lexer.c` is the first adapter-independent compiler component. It is
allocation-free, contains no module or declaration names, and tokenizes the
complete candidate punctuation/operator vocabulary with checked `U32` literals
and stable `A0-LEX-*` diagnostics.

`alpha/seki_parser.c` consumes that lexer in the live CLI and constructs a
fixed-capacity module prefix: the general header plus aliases, nominal types,
records, explicitly tagged variants, and exported kernel envelopes. Kernel bodies
for the minimum-age slice become a fixed-capacity tail AST. The independent
`alpha/seki_checker.c` resolves parameters and record fields, checks comparison
and condition types, and checks terminal decisions before the E0 adapter runs.
The rest of the expression language, typed-core construction, and C generation
remain adapter-backed until the general compiler core exists.
