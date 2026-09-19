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
`0.0.0-alpha.6` runs the general lexer/parser and the U8-decision semantic checker
before `alpha/seki_core.c` emits SCB-0 directly from the checked AST. The
immutable E0 frontend is no longer linked into `sekic`; its exact 417-byte output
remains a regression oracle. `alpha/seki_c_backend.c` independently reopens the
SCB-0 bytes into a restricted-C model, validates the complete slice, and emits
the exact established C. Neither E0 adapter is linked into `sekic`. Both
directions now derive module, type, field, variant, case, kernel, parameter,
literal, and rejection-tag identities from the program. This is an A0-02
increment, not its exit: the structural slice now permits canonically ordered U8
record fields and payload-free rejection cases, but still only one less-than
decision over a selected field.

`alpha/seki_lexer.c` is the first adapter-independent compiler component. It is
allocation-free, contains no module or declaration names, and tokenizes the
complete candidate punctuation/operator vocabulary with checked `U32` literals
and stable `A0-LEX-*` diagnostics.

`alpha/seki_parser.c` consumes that lexer in the live CLI and constructs a
fixed-capacity module AST: the general header plus aliases, nominal types,
records, explicitly tagged variants, and exported kernel envelopes. Kernel bodies
for the U8-decision slice become a fixed-capacity tail AST. The independent
`alpha/seki_checker.c` resolves parameters and record fields, checks comparison
and condition types, and checks terminal decisions. `alpha/seki_core.c` maps that
checked minimum-age AST to the exact established SCB-0 bytes, including a
source-derived threshold and declared resource ceilings. The rest of the
expression language and general typed-core construction remain open; C projection
is now independent but remains limited to the same structural slice. The original
minimum-age program retains its `seki_e0_*` C ABI solely as a byte-regression
compatibility case; other modules receive deterministic `seki_a0_<module>_*`
names.
The emitter derives field, constructor, and rejection-precedence indices and the
exact live-value bound from the AST. Alpha checks independently decode and
semantically reconstruct the nontrivial two-field/two-rejection artifact.
The live parser requires end-of-file after the supported module and rejects all
unknown or trailing top-level syntax.
