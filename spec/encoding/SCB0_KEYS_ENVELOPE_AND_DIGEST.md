# SCB-0 keys, envelope, and digest draft

- Status: accepted bootstrap candidate; non-normative; vectors not yet frozen
- Scope: canonical ordering, object framing, and v0 module digests

## 1. V0 natural-number ceiling

Every typed-core `Nat`, count, length, index, stable tag, version, and resource
quantity is encoded as one big-endian `U32`. An admitted v0 profile therefore
sets every corresponding ceiling at or below `4294967295`. Intermediate checker
arithmetic may use a wider representation, but a result outside `U32` rejects
rather than wraps or changes encoding.

This is a language-profile limit, not a host `size_t` assumption. Implementations
must apply the much smaller active byte and count ceilings before allocating or
iterating.

## 2. Typed canonical orders

Canonical tables compare decoded key values, not their length-prefixed encoded
bytes. All comparisons below are total.

`Name` compares its unsigned ASCII octets lexicographically. At the first unequal
octet, the lower octet sorts first; when one name is a prefix, the shorter name
sorts first.

Sequences compare element by element using their element order, with the shorter
sequence first when all elements in the shorter sequence are equal. Product
records compare fields in schema order. Tagged sums compare the numeric tag first
and then compare payload fields in schema order.

These rules induce the authority key orders:

```text
ModuleId       = path, version
FunctionKey    = base, labels
DigestId       = algorithm tag, digest octets
TypeRef        = local/imported tag, then case fields
DomainRef      = local/imported tag, then case fields
FieldOwnerRef  = owner tag, then case fields
FieldRef       = owner, field_index
VariantRef     = owner, stable_tag
SumTypeRef     = owner tag, then case fields
ConstructorRef = owner, stable_tag
Type           = type tag, then case fields recursively
```

Local reference cases compare their `U32` index. Imported cases compare
`ModuleId`, `DigestId`, then index. SHA-256 digest octets compare unsigned and
lexicographically. The order is structural and terminating because admitted
types are finite and nonrecursive.

A table sequence must be strictly increasing under its declared key order.
Equality or decrease rejects; the decoder never sorts it.

## 3. Envelope

Every standalone authority object uses this 13-octet header:

```text
offset  width  value
0       4      53 45 4b 49                 ;; ASCII "SEKI"
4       4      SCB schema version as U32   ;; exactly 0 for SCB-0
8       1      object kind                 ;; module=0, bundle=1
9       4      payload length as U32
13      n      payload
```

An envelope consumes exactly 13 plus its declared payload length octets. The
declared extent must fit the enclosing input. A standalone top-level decode also
requires that no octets remain after that envelope; a bundle decoder instead
continues with the next counted nested envelope. A wrong magic, unsupported
version or kind, oversized length, truncation, or top-level trailing octet
rejects at the envelope layer.

The module payload is the positional `Module` record in the schema ledger. Its
internal semantic `schema_version` remains an explicit `U32`. The singleton v0
`LanguageId` occupies zero octets in its schema position: selecting this SCB and
digest-domain version already selects its only possible value.

## 4. Digest identity and domain separation

V0 `DigestAlgorithm::sha256` always has exactly 32 digest octets. `DigestId`
therefore encodes its one-octet algorithm tag followed by exactly 32 octets, with
no payload length. A typed-core `Digest(sha256, length)` is admitted only when
`length = 32`.

The canonical module digest is:

```text
SHA256(
  ASCII("io.frogfish.seki/module/scb0/sha256") || 00 ||
  complete canonical SCB-0 module envelope
)
```

The `00` is one zero octet. The exact domain prefix prevents bytes from another
Seki artifact class or external protocol from being treated as a module digest.
Changing the algorithm, domain prefix, envelope, or module schema requires a new
versioned rule.

The digest cannot be stored inside the module it hashes. Imports store the exact
digest of each imported module. The root digest is computed by admission and
later manifests.

## 5. Bundle payload

The bundle payload is:

```text
root: ModuleId
modules: Sequence[complete SCB module envelopes]
```

Module envelopes appear in strict `ModuleId` order and contain exactly one root.
Each nested envelope supplies its own length, so the sequence adds only its `U32`
element count. The outer bundle envelope bounds the complete object.

Admission recomputes each nested module identity and digest, rejects duplicate or
unused modules, and computes the unique lexicographically least topological
admission order from the import graph. That context-dependent order is not stored
in module bytes.

## 6. Required vectors before freeze

- empty smallest valid module and its exact digest;
- one-module bundle and two-module imported bundle;
- every envelope field at boundary and malformed values;
- table keys differing by prefix, final octet, nested tag, and numeric version;
- digest substitution, wrong domain prefix, wrong length, and one-bit mutation;
- `U32` maximum and overflow in each semantic category; and
- independent encoder agreement on every byte and SHA-256 result.
