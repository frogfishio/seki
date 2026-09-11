# Seki lock JSON v0 draft

- Status: provisional, non-normative
- Trust: generated build evidence; never an admission input

## 1. Purpose

`seki.lock` lets humans review exact module identities and computed canonical-core
digests without placing digests in `.seki` source. Build tooling generates it
explicitly and may use it to assemble a closed bundle. The admission checker
ignores it and recomputes digests from the bundled SCB module bytes.

## 2. Document shape

The proposed document is a restricted canonical JSON object:

```json
{"schema":"io.frogfish.seki/lock@0","root":{"path":["acme","policy"],"version":1},"dependencies":[{"module":{"path":["seki","bounded"],"version":1},"sha256":"0000000000000000000000000000000000000000000000000000000000000000"}]}
```

The zero digest is illustrative and is not a valid dependency assertion.

The root is not repeated in `dependencies`. Dependencies appear in strict
`ModuleId` order and occur once. Paths contain only valid Seki ASCII segments.
Versions are exact `u32` natural numbers. A SHA-256 value is exactly 64 lowercase
hexadecimal digits until the digest registry is finalized.

## 3. Canonical text profile

Generators emit UTF-8 with:

- exactly the keys and key order shown by the schema;
- no insignificant whitespace;
- the shortest decimal form for versions, with no sign or leading zero;
- JSON escaping only where JSON requires it;
- one final LF after the document; and
- no byte-order mark, duplicate keys, extra keys, or trailing content.

Like [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785.html), this profile seeks
one reproducible JSON representation, but it is a smaller schema-specific format,
not a claim of JCS conformance. The fixed Seki rules are governing. All numbers
fit `u32`, and all semantic strings are ASCII, avoiding dependence on broader JSON
number and Unicode behavior.

## 4. Failure behavior

A locked build stops on a missing, malformed, stale, duplicate, extra, or
noncanonical lock entry and directs the user to run the explicit lock command.
It never rewrites the lock as an incidental build side effect and never silently
selects a different version or digest.

Because lock parsing is untrusted, accepting a lock does not establish semantic
authority. Only successful admission of the corresponding exact bundle does.
