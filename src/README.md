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
`0.0.0-alpha.3` runs the general lexer/parser and the minimum-age semantic checker
before `alpha/seki_core.c` emits SCB-0 directly from the checked AST. The
immutable E0 frontend is no longer linked into `sekic`; its exact 417-byte output
remains a regression oracle. Restricted-C projection and inspection still use
the E0 backend adapter. This is an A0-02 increment, not its exit: core emission
still recognizes only the minimum-age semantic shape.

`alpha/seki_lexer.c` is the first adapter-independent compiler component. It is
allocation-free, contains no module or declaration names, and tokenizes the
complete candidate punctuation/operator vocabulary with checked `U32` literals
and stable `A0-LEX-*` diagnostics.

`alpha/seki_parser.c` consumes that lexer in the live CLI and constructs a
fixed-capacity module AST: the general header plus aliases, nominal types,
records, explicitly tagged variants, and exported kernel envelopes. Kernel bodies
for the minimum-age slice become a fixed-capacity tail AST. The independent
`alpha/seki_checker.c` resolves parameters and record fields, checks comparison
and condition types, and checks terminal decisions. `alpha/seki_core.c` maps that
checked minimum-age AST to the exact established SCB-0 bytes, including a
source-derived threshold and declared resource ceilings. The rest of the
expression language and general typed-core construction remain open; C projection
is still adapter-backed until the general backend exists.
The live parser requires end-of-file after the supported module and rejects all
unknown or trailing top-level syntax.
