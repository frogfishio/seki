# ADR 0015: Structured admission-reason tags

- Status: accepted for bootstrap; registry freeze pending
- Date: 2026-09-11

## Decision

V0 admission reasons use a two-octet `(layer, reason)` identity. The high octet is
the existing fixed validation layer and therefore exposes primary rejection
precedence. The low octet identifies a stable reason within that layer.

Primary failure selection is lowest layer, least canonical structural path, then
lowest applicable reason at that exact path. Messages and source locations remain
untrusted diagnostics and do not affect the tag.

## Consequences

The registry can be reviewed layer by layer, and implementations can compare
results without comparing prose. A flat global enum, locale-sensitive message,
or implementation exception cannot silently become an admission result.

The assignments remain provisional until every tag has a hostile vector and
precedence tests. After that freeze, additions or semantic splits require a new
version rather than reuse of an old pair.

