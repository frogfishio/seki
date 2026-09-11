# Zing surface-language assessment

Status: Seki bootstrap lineage record

The incomplete Zing materials under `contrib/spec` are design evidence, not
normative Seki inputs. They provide a coherent and distinctive surface-language
vocabulary that Seki can reuse without inheriting Zing's runtime or systems
semantics.

## Adopt for the Seki draft

| Zing feature | Seki conclusion |
| --- | --- |
| `;;` line comments | Adopt. |
| Mandatory module declaration | Adopt and add semantic version/profile. |
| `::` module separator | Adopt as ASCII source spelling. |
| `.` declaration/statement terminator | Adopt. Newlines remain trivia. |
| Uppercase type names and lowercase value names | Adopt for v0. |
| `[...]` operation bodies and anonymous blocks | Adopt. |
| `Type[...]` generic application | Adopt for built-in bounded types. |
| `Type { field: value }` construction | Adopt with complete, unique fields. |
| Keyword selectors such as `findUnique:` | Adopt with static resolution only. |
| Unary field-like reads such as `candidate epoch` | Adopt as statically resolved projection. |
| Receiver-before-arguments, left-to-right message arguments | Adopt. Record fields instead use canonical label order. |
| Strict Boolean conditions | Adopt. There is no truthiness. |
| Nonescaping blocks | Adopt more narrowly: blocks are inline, immutable, and not first-class values. |

## Adapt rather than inherit

| Zing feature | Seki conclusion |
| --- | --- |
| Untyped operation heads | Require types on every parameter and result. |
| `:=` declaration-or-update | Use only for a fresh immutable local binding. Updating and shadowing are rejected. |
| Message lookup | Resolve statically from fields, intrinsics, and visible functions. No dynamic dispatch. |
| Arbitrary-width `iN`/`uN` families | Use the charter's fixed v0 integers: `U8` through `U64` and `I8` through `I64`. |
| Module `use` | Require exact module version and digest. |
| Boolean control messages | Retain expression-oriented `ifTrue:ifFalse:`; exclude statement-like one-arm forms initially. |
| Binary messages | Use a fixed conventional precedence table rather than Zing's single flat binary level. |
| Lexical closures | Capture immutable values and appear only as arguments to admitted intrinsics. |

## Exclude from Seki v0

- mutable locals and captured mutation;
- `ret`, including non-local returns from blocks;
- `whileTrue:` and general iteration;
- `to:do:` as a general loop;
- pointers, allocation, `free`, and host memory mutation;
- foreign imports and exports in kernel modules;
- protocols, instances, overloads, and dynamic method dispatch;
- strings, tagged strings, symbols, and heterogeneous shapes in the first core;
- escaping or stored closures and general function values;
- implicit integer conversions, truthiness, and target-sized integers; and
- customer-specific constructs from Gnosis, Kiku, or any other consumer.

Bounded traversal is exposed through a closed set of statically recognized
combinators such as `fold:with:`, `findUnique:`, `all:`, and `any:`. Each lowers
to an explicit typed-core node with a derived resource bound; it is not a
dynamically dispatched library message.

## Why this reuse is safe

The surface parser and elaborator are untrusted proof producers. Reusing or
adapting a Zing parser cannot make a surface parse authoritative: the verified
admission checker must reopen the proposed canonical typed core and reject any
ill-typed, effectful, unbounded, or falsely derived module.

## Source evidence

The main evidence used for this assessment is:

- `contrib/spec/zing-language-spec.md`;
- `contrib/spec/zing-language-decisions.md` (ZD-001 through ZD-007);
- `contrib/spec/zing-historic-message-model.md`;
- `contrib/spec/zing-language-conflicts.md`; and
- `contrib/spec/zing.peg`.

Open or conflicting Zing behavior is never silently treated as a Seki rule.
