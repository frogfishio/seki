# Tagged-form coverage closure lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/coverage_gaps.seki`
- Emitter: `tools/encoding/emit_coverage_gaps_scb0.mjs`

This compact fixture supplies positive canonical evidence for the final eleven
tagged-form gaps identified by `SEMANTIC_COVERAGE_V0.json`: six type tags, one
declaration tag, and four pure-term tags.

It contains `U8`, `U16`, `I8`, `I16`, `Bytes[3]`, `Digest[sha256,32]`, an alias,
a three-byte literal, `NotEqual`, `Not`, and `OrElse`. Its eight function bounds
are reconstructed by the ordinary semantic checker; the largest is the
256-bit digest identity function at 512 live bits.

The emitted module is 868 bytes and has domain-separated module digest
`70a10bb1cec408ecf8986ed6cdc25cf7d222e5372b9871bf5060ce7345189124`.
