# ADR 0011: Minimal typing and locked modules

- Status: accepted for bootstrap; not a language freeze
- Date: 2026-09-11

## Decision

Seki v0 has a syntax-directed type checker and a deliberately mechanical module
system. Neither is an extension point for an external type system, resolver, or
package manager.

The type system has no user-defined generics, polymorphic functions, overloads,
subtyping, traits, implicit conversions, or constraint solving. `Option[T]`,
`Result[T,E]`, arrays, bounded vectors, decisions, and bounded combinators are
closed built-in schema families, not a general generic facility. Every typed-core
instance is concrete and monomorphic.

Human-authored source imports an exact module identity/version under an explicit
local alias. It does not contain a digest. A generated, committed `seki.lock`
binds that identity to the digest of its canonical typed core. Aliases and source
locations do not enter semantic identity.

The admission checker receives the root and the complete finite dependency
bundle. It performs no filesystem search, network access, registry lookup,
version selection, or lock update. It recomputes module digests, requires one
module per exact identity, rejects cycles, and admits the graph from leaves to
root. All modules in a v0 bundle use the same semantic profile.

## V0 exclusions

- version ranges and automatic upgrades;
- wildcard, unqualified, conditional, or implicit imports;
- import search paths inside admission;
- module initializers and import-time execution;
- re-export and public-import chains;
- cyclic modules;
- imported kernels as callable functions;
- imported theorem namespaces; and
- network registries or package-manager behavior.

External systems such as Gnosis may resolve richer projects, instantiate their
own abstractions, and produce Seki source, lock candidates, typed core, or
witnesses. Seki independently rechecks the closed result and never requires
those systems.

## Consequences

The module proof is bounded graph validation plus exact qualified lookup. The
type proof is structural recursion over a closed node and type-constructor set.
This preserves useful reuse without turning Seki into a general type-system or
module-system project.

Canonical-core lock digests become operational only after F1-B selects the wire
encoding. Before then, lock generation is specification work and carries no
qualified reproducibility claim.
