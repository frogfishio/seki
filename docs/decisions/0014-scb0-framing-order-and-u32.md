# ADR 0014: SCB-0 framing, ordering, and `U32` naturals

- Status: accepted for bootstrap; vector freeze pending
- Date: 2026-09-11

## Decision

SCB-0 uses a fixed 13-octet envelope containing `SEKI` magic, a big-endian `U32`
schema version, a one-octet object kind, and a big-endian `U32` payload length.
Module and bundle objects have distinct kind values.

Every v0 typed-core natural, version, stable tag, index, count, length, and
resource quantity is a big-endian `U32`. Values or derivations beyond that range
reject. Active semantic profiles impose substantially smaller operational
ceilings before allocation or traversal.

Canonical tables use structural typed-key orders. ASCII names compare unsigned
octetwise; sequences and records compare lexicographically; sums compare tag then
payload. Producers must emit strict order, and admission never repairs it.

V0 module identity uses SHA-256 over an exact Seki module-domain prefix followed
by the complete canonical module envelope. A SHA-256 `DigestId` carries its
algorithm tag and exactly 32 octets without a redundant length.

## Consequences

The decoder needs no varint canonicality logic, host-width assumptions, generic
map ordering, or digest-length allocation. The `U32` ceiling is intentionally
conservative for a small kernel language and gives malformed inputs one obvious
representation.

The exact candidate bytes are now specified well enough to generate vectors, but
they are not frozen until independent encoders agree and hostile vectors exercise
every rejection boundary.

