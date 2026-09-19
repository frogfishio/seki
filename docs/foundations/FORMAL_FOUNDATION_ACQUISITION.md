# Formal-foundation source and acquisition record

- Status: B0 source identities bound; installations and qualification pending
- Date: 2026-09-19
- Machine lock: `foundations/FOUNDATION_LOCK.json`

## Decision

Seki binds Lean 4.30.0, Rocq 9.2.0, and CompCert 3.18 by upstream repository,
tag, resolved commit, exact downloaded source-archive bytes, and license-file
identity. The archives are not vendored in this repository. A version string or
package-manager name alone is never a foundation identity.

This record closes B0-08 and B0-09 at the source-selection and license-binding
level. It does not claim that the foundations are installed, built, clean-room
reproduced, or qualified. Those facts require separate installation manifests
and B0-13 clean-room evidence.

## Lean 4.30.0

The selected source is tag `v4.30.0`, resolved directly to commit
`d024af099ca4bf2c86f649261ebf59565dc8c622`. The downloaded codeload archive is
70,389,698 bytes with SHA-256
`c11edd040d77be85865e41b4a37a77d14f824c07d8642434eb3561163f2afa5d`.
Its root `LICENSE` is Apache License 2.0 and has SHA-256
`8b28515ffffc5c0fe2807d8ae3735b00b324d9b7ce807dd63ff6ac8922fbce7e`.

The local E0 proof was checked with Lean 4.33.1. That observation does not
satisfy this lock. Qualification must build or install exactly 4.30.0, record
its complete transitive inputs, and recheck the proof portfolio.

## Rocq 9.2.0

The selected release is annotated tag object
`f4392b61e195f1554260589b8778eec39c4834ac`, resolving to commit
`adfbf1855c348766beb4b790dcc8ebc02f908f63`. The official release archive is
6,559,931 bytes with SHA-256
`a45280ab4fbaac7540b136a6b073b4a6db15739ec1e149bded43fa6f4fc25f20`.
Its root `LICENSE` contains LGPL 2.1 and has SHA-256
`d4594b82f4d50840df6a7e9d14132a8c0a3cc05d0ac46d15310a264a1f75447e`.

The archive also contains component-specific license files. Any redistribution
or clean-room package must retain and inventory them; the root license label is
not permission to erase bundled-component notices. Rocq 9.2.0 is not installed
on the observed host.

## CompCert 3.18 acquisition and use policy

The public CompCert distribution is not free software as a whole. Its public
license permits educational, research, personal, and evaluation use but
prohibits commercial use unless the user has a separate AbsInt agreement. The
license lists particular files and directories—including the named Clight
semantics files—as separately available under LGPL 2.1-or-later, and identifies
other bundled licenses.

Seki therefore adopts this policy:

1. The Seki repository and ordinary source distributions do not vendor or
   redistribute the full CompCert archive, binaries, or proof tree.
2. CompCert is a user-supplied formal foundation. A build requiring it accepts
   an explicit `COMPCERT_ROOT` selected by the operator and records the supplied
   tree identity and license provenance.
3. Noncommercial research/evaluation may use the public distribution only
   under its own terms. Seki's GPL license does not replace or broaden those
   terms.
4. Commercial qualification requires an appropriate AbsInt agreement or a
   separately reviewed proof-source closure consisting only of files whose
   applicable licenses permit that use. Seki does not assume that such a
   closure exists merely because several Clight files are dual-licensed.
5. Seki does not redistribute an extracted “free subset” until its complete
   transitive file and license closure has been audited and recorded.
6. CompCert compilation remains an optional stronger native path. The F4
   Clight semantic/refinement work still requires an exact lawful CompCert
   foundation supplied under this policy.
7. No automated download implies acceptance of the CompCert license. Future
   acquisition tooling must display the upstream terms and require an explicit
   operator choice.

This resolves B0-10's project policy without claiming commercial rights or an
installed foundation.

## Controlled CompCert identity finding

The official CompCert site names version 3.18 and links tag `v3.18`; that tag
resolves to commit `14d616046360a0b2611ebdfc2f98368af402e1f7`, and its changelog
begins with “Release 3.18”. However, the exact archive's root `VERSION` file
contains `version=3.17`.

The lock therefore identifies CompCert by tag, commit, archive SHA-256, and
license SHA-256. The internal `VERSION` field is recorded as contradictory and
must not be used alone for admission. Any installed `ccomp` identity check must
account for this upstream discrepancy rather than silently normalizing it.

The downloaded source archive is 1,917,028 bytes with SHA-256
`564b312b3ed3162f02605f0108feb555bd28fe7a80b97ea269c546bcc60c1cf0`.
Its root license has SHA-256
`40e8151cb26269a4e051309a958714191a706b5dfc7aaec00a61137cb338a648`.

## Remaining qualification work

- build Lean 4.30.0 and Rocq 9.2.0 from the exact locked sources in a pinned
  clean-room environment;
- bind OCaml, C/C++, CMake, Ninja/Make, libc, and other transitive build inputs;
- decide whether qualification uses a licensed full CompCert installation or
  a reviewed LGPL-compatible proof-source closure;
- record installed-tree and executable identities separately from source
  archive identities;
- rerun proof and hostile portfolios under the pinned tools; and
- retain every upstream notice required by the selected distribution profile.

No foundation in this record has implementation, proof, product, or production
authority yet.
