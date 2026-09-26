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
`0.0.0-alpha.7` runs the general lexer/parser and the U8-decision semantic checker
before `alpha/seki_core.c` emits SCB-0 directly from the checked AST. The
immutable E0 frontend is no longer linked into `sekic`; its exact 417-byte output
remains a regression oracle. `alpha/seki_c_backend.c` independently reopens the
SCB-0 bytes into a restricted-C expression and tail AST, validates the complete
slice, and emits the exact established C. Because it decodes a tree rather than
one fixed byte sequence, kernel control nests to arbitrary depth within its
fixed arena. Neither E0 adapter is linked into `sekic`. Both
directions now derive module, type, field, variant, case, kernel, parameter,
literal, and rejection-tag identities from the program. This is an A0-02
increment, not its exit: the structural slice now permits canonically ordered U8
record fields and payload-free rejection cases, but still only one less-than
decision over a selected field.

`alpha/seki_lexer.c` is the first adapter-independent compiler component. It is
allocation-free, contains no module or declaration names, and tokenizes the
complete candidate punctuation/operator vocabulary with checked `U32` literals
and stable `A0-LEX-*` diagnostics.

`alpha/seki_types.c` is the shared resolved-type layer. It interns each module's
value types once, so exact normalized identity is an integer comparison, and it
implements the canonical `value_bits` width used by the resource-cost algebra.
Its `kind` field carries the SCB-0 `Type` discriminant directly, so the emitter
writes it without a translation table.

`alpha/seki_parser.c` consumes that lexer in the live CLI and constructs a
fixed-capacity module AST: the general header plus aliases, nominal types,
records, explicitly tagged variants, and exported kernel envelopes. Kernel bodies
for the U8-decision slice become a fixed-capacity tail AST. The independent
`alpha/seki_checker.c` is the module's elaborator: it resolves parameters, record
fields, environment slots, variant tags, and precedence indices, checks
comparison and condition types and terminal decisions, and derives the exact
resource bounds from the published cost algebra. It records one resolution per
expression node, and `alpha/seki_core.c` constructs SCB-0 by recursive traversal
of that elaboration without resolving any name a second time. The two components
therefore cannot disagree about what a program means. The rest of the expression
language and general typed-core construction remain open; C projection is now
independent but remains limited to the same structural slice. The original
minimum-age program retains its `seki_e0_*` C ABI solely as a byte-regression
compatibility case; other modules receive deterministic `seki_a0_<module>_*`
names.
The emitter derives field, constructor, and rejection-precedence indices and the
exact live-value bound from the AST. Alpha checks independently decode and
semantically reconstruct the nontrivial two-field/two-rejection artifact.
The live parser requires end-of-file after the supported module and rejects all
unknown or trailing top-level syntax. Recursive descent is bounded by the
profile's `maximum_nesting` ceiling, so no source inside the host size limit can
exhaust the stack.

Canonical table ordering belongs to `alpha/seki_core.c`, not to the author:
declarations, record fields, and variant cases are sorted by their typed keys
before emission and every reference uses the canonical position. The host owns
the parsed module and elaboration workspace, so no component below `main`
carries those multi-megabyte objects on its own frame.
