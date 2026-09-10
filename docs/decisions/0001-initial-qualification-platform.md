# ADR 0001: Initial qualification platform

- Status: accepted for bootstrap
- Date: 2026-09-11

## Decision

The first reproducible qualification platform will be Linux x86-64. macOS may
be used for development, but a successful macOS build does not substitute for
the Linux qualification record.

CI begins on GitHub's `ubuntu-24.04` x86-64 environment. Before any native or
production authority claim, the project must replace moving runner labels with
a checksum-closed environment whose operating system, toolchain, dependencies,
and build inputs are exactly identified.

## Reason

Linux x86-64 provides a practical clean-room environment and broad toolchain
availability. Naming one initial target keeps the early proof and
reproducibility boundary finite.

