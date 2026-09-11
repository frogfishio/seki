# ADR 0006: Transient Zing bootstrap contribution

- Status: accepted
- Date: 2026-09-11

## Decision

The local `contrib/` Zing material is temporary, ignored bootstrap reference. It
is not a project dependency, normative input, vendored component, distributable
artifact, or required build input. Seki does not need to carry it after the
surface-language bootstrap.

Every conclusion Seki retains from that review is independently stated in
project-owned specifications and decisions. No Seki build, verification command,
or qualification claim may require the local contribution to be present.

## Consequences

- `contrib/` remains ignored by version control.
- Seki specifications must be complete without following a `contrib/` path.
- The lineage assessment may name the historical evidence but is informative.
- Future syntax decisions cite Seki ADRs and specifications, not Zing documents.
- Removing the local contribution must not change any tracked artifact or check.

