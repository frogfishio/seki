# ADR 0021: Build a usable provisional alpha before F0 review

- Status: accepted for bootstrap; no implementation or qualification authority
- Date: 2026-09-19

## Context

Global F0 asks a materially different consumer to judge whether Seki's charter
and proposed kernel boundary fit a real decision. That review cannot be useful
while Seki offers only design documents and a single closed-shape experiment.
The likely reviewers will engage after there is a compiler they can build, run,
and try on their own decision.

Requiring F0 acceptance before writing any reusable compiler therefore creates
a circular dependency: the project waits for feedback that consumers cannot
reasonably provide until the project supplies a usable artifact.

The seed still correctly forbids reporting F1 as started or authorized before
F0 closes. The solution is not to weaken F0 or rename unreviewed work as F1.

## Decision

Seki adds bootstrap track `A0`, a provisional usable alpha. A0 may proceed while
global F0 remains open. It exists to create the concrete artifact against which
consumer feedback and F0 acceptance can be obtained.

The alpha must:

- provide one general `sekic` command rather than a program-shaped translator;
- compile both the minimum-age kernel and the proposed Grit Stage 1 publication
  coordinator;
- parse and type-check only a documented monomorphic subset;
- emit deterministic candidate typed-core bytes and restricted ISO C11;
- reject unsupported, malformed, ambiguous, and out-of-profile input;
- include runnable examples, hostile tests, build instructions, and an explicit
  trust/claim notice; and
- be packaged so a consumer can build and exercise it without understanding the
  repository's research fixtures.

A0 is allowed to refactor and generalize E0 code. It may change source syntax,
typed-core bytes, C ABI, diagnostics, and CLI behavior between alpha revisions.
Nothing in A0 freezes the language or satisfies an F1 entry or exit criterion.

## Claim ceiling

An A0 artifact may be called `experimental`, `prototype`, `alpha`, `generated`,
or `runnable` when those descriptions are factually scoped. It must not be called
`admitted`, `proved`, `certified`, `verified`, `qualified`, `production-ready`,
or suitable for authority-bearing use.

In particular:

- the bootstrap C frontend and backend remain trusted and unproved;
- a Lean theorem about a candidate typed-core artifact does not yet prove the
  emitted C or native binary;
- tests provide engineering evidence, not compiler-correctness proof; and
- consumer success or approval may close F0 only through its existing exact,
  checksum-bound acceptance procedure.

`seki_f1_implementation_authorized` and every authority field in
`PROJECT_STATUS.json` remain false while F0 is open.

## Consequences

The immediate dependency is now productive: build and internally attest the
release candidate, give those exact bytes to real consumers for field use, use
their findings to correct the product, then record the scoped F0 evidence and a
separate go-live decision. ADR 0022 defines this sequencing. Work that depends
on a formal phase's authority still waits for its exact gate.
