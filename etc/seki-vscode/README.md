# Seki syntax highlighting

A VS Code extension contributing a TextMate grammar for the Seki language, so
that `.seki` files are syntax highlighted.

Scaffolded with `yo code` (`generator-code`, "New Language Support").

## What it highlights

The grammar follows `spec/language/seki-v0.peg` and the alpha lexer in
`src/alpha/seki_lexer.c`:

| Construct | Example | Scope |
| --- | --- | --- |
| Line comments (the only comment form) | `;; note` | `comment.line.double-semicolon.seki` |
| Module / import paths | `module seki::fixtures::x`, `use a::b @ 1 as b` | `entity.name.namespace.seki` |
| Header clauses and their name lists | `profile:`, `claims:`, `requires:` | `keyword.control.header.seki`, `support.constant.property.seki` |
| Type declarations | `export record Pair`, `export variant Denial` | `storage.type.seki`, `entity.name.type.seki` |
| Function / kernel declarations | `export fn leftOrZero`, `export kernel authorise` | `storage.type.function.seki`, `entity.name.function.seki` |
| Contract clauses | `bounded`, `steps:`, `liveBits:`, `controlDepth:`, `workspaceBits:`, `rejects:` | `keyword.other.contract.seki` |
| Arithmetic / publication policies | `arithmetic: checked`, `publication: eligible` | `support.constant.policy.seki` |
| Control keywords | `match`, `require`, `else:`, `accept`, `reject` | `keyword.control.seki` |
| Keyword-message selectors | `ifTrue:`, `findUnique:`, `value:` | `entity.name.function.selector.seki` |
| Block parameters | `[ :item \| item ]` | `variable.parameter.seki` |
| Primitive and builtin types | `U32`, `Bool`, `Decision`, `Array`, `Digest` | `support.type.primitive.seki` |
| Digest literals | `sha256:"00ff"` | `support.function.digest.seki`, `string.quoted.double.seki` |
| Bytes literals | `bytes[53 45 4b]` | `support.function.bytes.seki`, `constant.numeric.hex.seki` |
| Operators | `->`, `:=`, `::`, `==`, `\|\|`, `&&` | `keyword.operator.seki` |

Seki has no block comments and no general string literals; the only quoted form
is the hex payload of a digest literal.

## Trying it

From this folder, press <kbd>F5</kbd> ("Extension"). That opens a second VS Code
window with the extension loaded and `spec/language/examples` opened, so you can
click through the fixtures.

To use it in your normal editor instead, symlink it into your extensions folder
and restart VS Code:

```bash
ln -s "$PWD" ~/.vscode/extensions/seki-vscode
```

## Packaging

`package.json` deliberately has no `publisher` field. Add one before running
`vsce package`.
