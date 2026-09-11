# Type and module complexity review

- Date: 2026-09-11
- Scope: v0 language and trusted-boundary complexity ceiling
- Disposition: minimal monomorphic typing and locked modules accepted for bootstrap
- Authority: no implementation, proof, resolver, or package-manager claim

## Decision reviewed

Seki needs enough typing to reject malformed kernels and enough modularity to
reuse exact declarations. It does not need a research type system or an enterprise
package environment.

The accepted cut is:

- syntax-directed checking over fully concrete types;
- closed built-in parameterized schema families;
- no user-defined generics or polymorphic functions;
- exact-version, explicitly aliased source imports;
- generated canonical-core digests in committed `seki.lock`;
- one complete finite dependency bundle supplied to admission; and
- deterministic digest, profile, export, direct-reference, and DAG validation.

## Human and authority boundaries

Humans edit module identities, versions, and aliases. Tooling computes digests.
A locked build never silently changes them. The admission checker trusts neither
the resolver nor the lockfile: it recomputes the supplied module digests and
validates the whole closure.

External systems, including Gnosis, may be sophisticated Seki producers. Their
successful analysis is not a premise of Seki admission, and Seki can be built,
checked, and specified without them.

## Complexity deliberately excluded

- generic declaration checking and specialization;
- unification, constraints, traits, overloads, and implicit conversions;
- semver solving and version ranges;
- filesystem or registry resolution in the checker;
- re-export, wildcard import, implicit visibility, and module initialization;
- cross-profile module negotiation; and
- theorem import or proof search through the source module system.

## Remaining work

- Complete the provisional SCB-0 field/tag ledger and canonical witness form
  before a byte freeze; keep the JSON lock outside admission.
- Specify stable module/lock rejection tags and hostile encoded vectors.
- Define the initial local-workspace command and project-file format outside the
  trusted boundary.
- Validate the system with a two-module candidate fixture after encoding is
  selected.

## Conclusion

The proposed module checker is bounded graph validation, not a package manager.
The proposed type checker is structural recursion, not a constraint solver. This
is compatible with Seki's deliberately small proof kernel and still permits
enterprise systems to use it without becoming dependencies.
