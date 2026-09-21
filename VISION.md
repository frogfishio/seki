# Seki: vision

*A draft for discussion with the projects that intend to use Seki. It sets out
what we think Seki is for, how its assurance is meant to work, and why. It is
explicit about which parts exist today and which do not. We would rather be
told now that part of it is wrong than find out after building it.*

---

## Summary

Seki is a deliberately small language for writing **decision kernels**: small,
bounded functions that take a fixed set of facts and return either an
acceptance or a specific, stable rejection. Seki compiles a kernel to ordinary
portable C11 that any project can build.

The point of Seki is not the C. It is what comes with the C:

> A customer can receive a tiny decision kernel as ordinary, stable C, together
> with independently checkable evidence of exactly what that kernel means,
> without adopting or trusting a large language ecosystem.

Or, positioned against the nearest neighbour:

> Dafny helps you develop verified software. Seki lets you ship a small,
> checksum-bound, proof-carrying decision as portable C.

Assurance rests on **two separate proofs**. A *program proof*, per kernel,
shows that the exact kernel satisfies a requirement stated independently in
Lean. A *compiler proof*, made once, shows that compilation preserves a
kernel's meaning. Together they carry the requirement to the generated C.

Behind that sits a view about **trust** that shapes everything else. A proof is
only worth what its provenance is worth. So every part of Seki's assurance is
either **borrowed** from tools the field already trusts, used unmodified, or
**earned** in the field by running beside an existing implementation. Nothing
is self-certified.

**Where we are:** a working alpha compiler exists, with a stable decision ABI,
a frozen host-boundary contract and reproducible bundles. The two proofs do not
yet exist for customer kernels. This document describes the target; the
section *Where we are today* describes the present, and the two should not be
confused.

---

## 1. The problem

Critical systems are full of small decisions. May this artifact be published?
Is this operation authorised under this policy? Is this projection permitted?
The decision is usually a handful of handwritten branches, and its correctness
rests on tests.

Tests sample:

```text
selected inputs  →  black box  →  observed outputs
```

If the chosen outputs match expectation, we have evidence about the chosen
inputs. Nothing is established about the rest, and undefined behaviour or an
environmental dependency can sit behind every passing test. A black box can be
wrong and pass its suite.

Seki aims to replace sampling with reasoning about meaning:

```text
every admitted input  →  the program's formally defined meaning  →  a theorem
```

This does not make a kernel correct. It moves the question. Instead of *"did
we test enough cases?"* the question becomes *"did we state the right
requirement?"* That is a better question to be left with. A requirement can be
read, argued about and reviewed by the people who own the policy. A test suite
cannot tell you what it failed to cover.

It is also, plainly, the next level of assurance beyond what projects usually
have, rather than a replacement for everything else:

```text
Tests             "for these chosen inputs, we observed the expected outputs"
Program proof     "for every admitted input, the program satisfies the requirement"
Compiler proof    "the generated C preserves the proved program's meaning"
```

Examples still validate intent, and ordinary integration tests still check the
surrounding system. Seki closes the large gap between them.

---

## 2. What Seki is, and what it is not

A Seki kernel takes one record of facts and returns a decision:

```seki
export kernel authorise request: Request
-> Decision[Permit, Denial]
...
rejects: Denial::UnknownAccount, Denial::Underage, Denial::TierTooLow
publication: none [
  account := request account.
  require account == (request boundAccount) else: Denial::UnknownAccount.
  require (request age) >= 18 else: Denial::Underage.
  require (request tier) >= 100
    else: Denial::TierTooLow(limit: 100, actual: (request tier)).
  accept Permit { account: account, grantedTier: (request tier) }
].
```

It compiles to C that needs only `<stdint.h>`: no allocation, no recursion, no
unbounded loops, no library calls. The result is a fixed-layout decision
reporting whether the kernel accepted, which rejection applies by an explicitly
authored tag, which premise failed, and typed detail about why.

Seki is **not** a general-purpose language. It has no functions, arrays or
traversal, no `Option` or `Result`, no imports, generics, type inference,
mutation, recursion, unbounded loops, floating point or effects. One kernel per
module.

These omissions are the design, not a list of things still to do. Section 12
explains why.

---

## 3. How assurance works: two proofs

A kernel's assurance rests on two separate claims.

```text
P satisfies the requirement R            ← the program proof, per kernel
              +
compilation preserves P's meaning        ← the compiler proof, once
              =
the generated C satisfies R
```

### The program proof

This is what a customer actually buys.

A requirement is stated in Lean, independently of any program. It describes a
property any decision function might have:

```lean
def SafePolicy (f : Applicant → Decision) : Prop :=
  ∀ applicant, applicant.age < 18 → f applicant ≠ .approve
```

That definition says nothing about Seki. It is a statement about what "safe"
means.

Separately, someone writes a Seki kernel. Lean does not read the source text.
It decodes the kernel's exact canonical bytes into Seki's formal syntax:

```lean
def P : Seki.Program := decode kernelBytes
```

Because Seki's semantics is defined in Lean, Lean can interpret that program as
a function, `Seki.eval P : Applicant → Decision`, and the requirement can be
applied to it:

```lean
theorem kernel_is_safe : SafePolicy (Seki.eval P)
```

If that proof closes, Lean has established: *under Seki's formally defined
semantics, this exact program satisfies this requirement, for every input.*

Proving it may involve symbolic reasoning, enumerating a bounded input space,
or checking a certificate the tooling generates. Because Seki is small, total
and bounded, much of that can be automated. But each property still needs its
own proof: understanding what a program means does not by itself prove that the
program is good.

### The compiler proof

This is proved once, for every program that will ever be written:

```lean
theorem compile_correct :
  ∀ P x, C.exec (compile P) x = Seki.eval P x
```

It says nothing about whether any program is good. It says only that
compilation does not change what a program means.

### Putting them together

```text
SafePolicy (Seki.eval P)
       +
C.exec (compile P) = Seki.eval P
       ↓
SafePolicy (C.exec (compile P))
```

The generated C satisfies the requirement for every input, although nobody ever
reasoned about that C directly.

Neither proof substitutes for the other. A proved compiler faithfully compiles
a wrong program. A proved program says nothing about what was emitted. A kernel
needs both.

---

## 4. The authority is the typed core, not the source

Seki source text is a developer interface. When a kernel is compiled, the first
thing produced is a **canonical typed core**: an exact, checksum-bound binary
encoding of the program's meaning. That typed core is the authority.

Everything downstream is anchored to it:

- the program proof is about the typed core Lean decodes, not the text;
- the compiler proof takes the typed core as input;
- a delivered bundle binds the typed core by digest.

This has a useful consequence. The parser and elaborator that turn source text
into typed core **do not need to be trusted or proved**. They only need to
produce a typed core, which is then independently decoded, checked and bound.
If they are wrong, they produce a typed core that says something other than the
author intended — and the program proof, which is about the typed core, will
catch that against the requirement.

The one discipline this imposes is absolute: the program that is proved and the
program that is compiled must be *the same bytes*. Lean decodes the canonical
encoding directly. Nothing is ever transcribed by hand. Otherwise it would be
possible to prove a fact about one program and ship another.

---

## 5. Independent authorship

The requirement and the kernel should be written by different people.

```text
Policy owner / verifier   →  the Lean requirement
Implementation author     →  the Seki kernel
Lean                      →  referees their agreement
```

If they disagree, the proof fails. That is the purpose. The requirement and the
kernel are two independent readings of the same intent, and Lean acts as a
strict referee between them rather than a participant in either.

The failure this guards against is the oldest one in formal methods, and it is
worth naming. *What the thinker thinks, the prover proves.* A team that writes
the semantics, the program and the proof has built a closed loop. The proof
will confirm what they already believed, because it cannot do otherwise.
Separating the authors breaks that loop at the level that matters most: intent.

They need not always be different people. But every time they are the same
person, the assurance is weaker than it looks, and it is better to know that.

### Requirements must be falsifiable

A requirement can be true and empty. *"No minor is ever approved"* is satisfied
perfectly by a kernel that approves no one. So each requirement should carry a
companion that makes it falsifiable — here, *"every adult is approved"* — so
that it cannot be met by doing nothing.

This is also where examples keep their role. Concrete cases test the
**requirement**: whether it captures what anyone actually meant. The proof then
covers every case the requirement describes. Examples catch misunderstanding;
proof catches omission.

---

## 6. Proof is not trust

This distinction took us a while to see clearly, and it changes how Seki should
be adopted.

A project replacing handwritten decision logic with Seki is not replacing an
unproven system with a proven one. The existing logic **is** proven — not
mathematically, but empirically. It has run in production without failing.
Field history is a real form of proof, and it is the one form a new system
cannot have.

So when a project says Seki is *"not authoritative enough for production yet"*,
the precise word is not *unproven*. It is **untrusted**. And what is untrusted
is not the kernel's logic. It is the evidence offered for it.

Evidence produced by a project, about itself, using tools it wrote, is not
trustworthy to a stranger. Not because it is wrong, but because a stranger has
no reason to believe it beyond the project's own word. A thousand tests written
by the same people who wrote the compiler, checked by a second implementation
the same people also wrote, is a closed loop however large it grows.

That is why the shape of Seki's assurance matters more than its volume.

---

## 7. Where trust comes from: borrowed and earned

Every part of Seki's assurance is one of two things.

### Borrowed

Trust borrowed from tools the field already trusts, **used unmodified**.

**Lean's kernel** checks every proof. It is small, it is scrutinised by a large
mathematical community that depends on it, and independent checkers reimplement
it. If it were wrong, a great deal of mathematics would fall, so a great many
people are motivated to find out.

**CompCert**, where machine-level closure matters, is the compiler whose
verified core famously resisted the random-testing campaigns that found hundreds
of defects in mainstream compilers, and it has decades of industrial use.

Their trust is not ours. It comes from everyone else who has staked something on
them. Even if they are wrong, that risk is shared, known and socially
distributed, rather than borne privately by whoever trusted Seki.

Borrowed trust survives only while the trusted thing is used as it is. The
moment Seki adds an axiom, patches a toolchain, or reaches around the kernel to
save effort, it stops borrowing and starts self-certifying again. That rule is
simple and absolute.

### Earned

Trust earned in the field, by running Seki beside an existing implementation as
a **shadow**: comparing every decision, stopping on every disagreement, and
investigating each one until agreement has accumulated.

A shadow period is not a stage to be got through. It is one of only two sources
of trust available at all.

### Nothing self-certified

Put together, the rule is: **every part of the assurance story is either
borrowed or earned.** Seki can never become trusted by producing more evidence
of its own.

---

## 8. The compilation chain in full

```text
Seki source text
    │  parser and elaborator             untrusted; not the authority
    ▼
canonical typed core                     THE AUTHORITY, bound by digest
    │  Seki.eval, defined in Lean        our definition; kept small and legible
    ▼
decision function
    │  compile, proved once in Lean      borrowed trust: Lean's kernel
    ▼
restricted C
    │  C compiler                        trusted and recorded, or CompCert
    ▼
machine code
    │  processor                         a physical limit; evidenced by execution
    ▼
decision
```

Each link rests on something different, and it is worth being exact about what.

### The compiler that runs stays untrusted

Seki's working compiler can be fast, convenient and conventionally written. It
is never trusted.

The authority is a `compile` function **defined in Lean** and proved correct
once. For each kernel, Lean's kernel checks that the working compiler's output
is exactly what that verified function produces, by direct reduction. The
working compiler only has to agree with the verified one.

This matters for how failure looks. A bug in the working compiler produces an
artifact that **fails to check** — a rejection — not a plausible kernel that
quietly decides wrongly. The worst a compiler bug can do is cost time.

It also keeps all of the proof in one foundation. The requirement, Seki's
semantics, the program proof and the compiler proof all live in Lean. There is
no bridge between proof assistants on the essential path.

### The C semantics is the link we cannot borrow

The compiler proof needs a formal definition of what the generated C means. If
we write that definition ourselves, it is ours, and its trust cannot be
borrowed. It is the one link in the chain exposed to the closed-loop problem.

Two things limit that exposure. First, it is kept very small. Seki emits a tiny
fragment of C: struct field reads, integer comparisons, `&&` and `||`,
conditionals, a `switch` on a tag, assignments to a result, and three fixed
bounded loops. No floating point, no undefined arithmetic, no allocation, no
recursion. A definition of that fragment is small enough for a stranger to
check by reading it. Second, it is checked against execution rather than taken
as definitional.

---

## 9. The two roles of CompCert

CompCert appears in Seki in two distinct roles. Separating them clears up most
confusion about it.

### Role one: a formal meaning for the generated C

*"We emit correct C"* is otherwise vague. ISO C is large and full of undefined
and implementation-defined behaviour. CompCert includes **Clight**, a restricted
C with a mechanised operational semantics written and scrutinised by other
people.

Constraining Seki's output to a Clight-compatible fragment, and proving against
Clight's semantics rather than our own, has two benefits. It gives the generated
C an established mathematical meaning. And it removes the one link we otherwise
could not borrow: the C semantics would then be someone else's, which is exactly
the independence the closed-loop problem calls for.

### Role two: compiling that C to machine code

Once the C is proved, it still has to be compiled.

```text
Using GCC or Clang:
  requirement proof → proved C → trusted, recorded compiler → binary

Using CompCert:
  requirement proof → proved Clight → verified CompCert → binary
```

With GCC or Clang, the proof ends at the C abstract machine and the compiler is
trusted not to miscompile — which mainstream compilers occasionally do. With
CompCert, its verified compilation theorem carries the semantics down toward
machine code, substantially shrinking what must be trusted downstream.

Using CompCert for native compilation is a **stronger, optional** deployment
profile, not a precondition. The initial profile trusts and records a
conventional compiler.

### Licensing

CompCert's licence permits non-commercial use without further agreement;
commercial use requires one from its owner. Seki does not redistribute
CompCert. A project that wants it installs it itself, under whichever terms
apply to that project — so whether a separate agreement is needed is the
project's question, and depends on how that project uses it.

---

## 10. Evidence is complete along different axes

No single kind of evidence covers everything. The kinds available cover each
other's blind spots.

| | Inputs covered | Depth covered |
| --- | --- | --- |
| Lean proof | every input | down to a model of the C |
| CompCert | every input | from the C down to a model of the machine |
| Differential execution | only those run | the whole stack, including the actual processor |

A proof is complete in inputs and stops at a model. Execution reaches the real
hardware but covers only what was run. Neither alone is enough; together they
leave little uncovered.

**Differential execution** means compiling the generated C, running it, and
comparing every result against Lean's evaluation of the same kernel on the same
input. Because Lean's evaluator is derived from the typed core rather than from
anyone's reading of the source, the two sides are genuinely independent.

For a kernel with a small input domain, execution can be **exhaustive**. A
kernel deciding on one `U8` value has 256 possible inputs; all 256 can be run at
every optimisation level, and then nothing is left to wonder about for that
kernel, on that processor, with that compiler.

---

## 11. There is a physical limit

No chain of proof reaches the machine.

CompCert is proved correct against a *model* of the instruction set. The model
is not the silicon. Different processors implementing nominally the same
instruction set do diverge: every generation ships with errata, some
instructions have behaviour the architecture leaves undefined and
implementations fill in differently, and floating-point results can depend on
the implementation. A processor from one decade and one from the next do not
execute code identically in every respect.

That limit is real, but it is small and rare. **Specification error is neither.**
It is where formal methods actually fail: the proof is valid, the theorem is
true, and the theorem is about something other than what was shipped — because
a person wrote a theorem believing the semantics was simpler than it was.

So Seki's defences are aimed at specification error first: independent
authorship, falsifiable requirements, and execution on the real target. Not
more proof.

It also means Seki must never claim to be *"verified"*. Its claim has a shape:

> **Proved relative to a stated model, and executed on a named target with a
> named toolchain.**

The target and toolchain are part of the evidence, not context around it.

### Seki avoids most divergence by construction

The fragment of C that Seki emits stays well inside the part of the instruction
set every implementation agrees on. It has no floating point, so no precision
divergence. Its arithmetic is checked, so there are no undefined shifts or
overflow. It uses no bit-scan or exotic instructions. This is a consequence of
totality and checked arithmetic rather than a separate design goal — which is
exactly why it should be written down and checked, so that it does not quietly
stop being true.

### A security property is a separate obligation

Seki compares identities such as digests in code whose running time does not
depend on where the first differing byte lies. That is true of the C Seki
emits. It is **not** established by any proof in this chain. A proof that the C
means the same as the kernel says nothing about how long it takes, and compiler
optimisation and processor behaviour are precisely where data-independent
source can become data-dependent execution. If a project comes to rely on it,
it needs its own argument, from inspection of the emitted machine code or
from timing evidence, and should be treated as a distinct commitment.

---

## 12. Why the language is small

Every feature Seki omits is a kind of reasoning nobody has to do.

- **No loops** except a few fixed, bounded ones: every kernel terminates, and
  its cost can be derived exactly.
- **No recursion or allocation**: its memory use is fixed and known.
- **No functions or imports**: a kernel's meaning is entirely on the page.
- **No floating point**: no precision behaviour that differs by processor.
- **No mutation or effects**: evaluation depends on nothing but the input.

A kernel that cannot loop, allocate or call out is a kernel whose behaviour is
total, whose cost is derivable, and whose meaning is small enough to reason
about completely. That is what makes the program proof tractable at all, and
what keeps the C semantics small enough to read.

The surface is therefore fixed by agreement rather than grown by request. If a
decision needs traversal, recursion or arbitrary computation, that is not a gap
in Seki. It is a sign that the decision is not a kernel, or that it should be
split so that a bounded kernel makes the part that carries authority. Seki is
meant to sit beside general-purpose code, deciding the one bounded thing that
must be right, while that code does everything else.

---

## 13. The host boundary

A kernel does not authenticate anything.

It cannot verify a signature, recompute a digest, read a file, consult a clock,
or observe anything outside the one record it is given. A kernel consumes
identities the host **has already authenticated**, and decides only whether they
stand in the relationships its policy requires.

Authority for authentication rests entirely with the host. Seki narrows what a
decision means. It does not widen what the host has established.

### Identities carry evidence; Booleans do not

Seki's **nominal** types are the evidence-bearing inputs. Two nominal types over
the same representation are distinct: a kernel cannot be written that accepts a
package identity where an artifact identity was required, even though both are
32-byte digests. That is enforced when the kernel is checked, so no generated
kernel ever compares them.

It is worth being exact about what this does and does not cover. It is a
guarantee about **what the kernel does**. It is not a property of the C type
system: in C, two such types are interchangeable, and C will not stop a host
from putting a device identity into an account-identity field. Filling the
record correctly remains the host's responsibility, like authenticating what
goes into it.

A **Boolean** input carries no evidence. It is the host asserting a verdict the
kernel cannot examine. A kernel whose decision turns on
`receiptValid: Bool` has handed the decision back to whoever set that field and
adds nothing.

So hosts should pass the identities and quantities a policy is *about*, and let
the kernel state their relationships. Passing the two identities and letting the
kernel compare them keeps the authority where the proof can see it.

---

## 14. Adopting Seki: the shadow period

We expect projects to adopt a Seki kernel in shadow first.

```text
existing implementation   →  decision  ─┐
                                        ├─ compare every result
Seki kernel               →  decision  ─┘
```

Every disagreement stops qualification without affecting what is published, and
is investigated. The existing implementation keeps making the real decision.

### Why shadow rather than primary

Not because Seki is unproven — the existing implementation has no mathematical
proof either. Two reasons survive scrutiny:

- **Churn.** Until the language, encoding and decision ABI are frozen together, a
  primary integration breaks whenever they change. A shadow absorbs that.
- **Asymmetric failure.** A wrong primary decision publishes something wrong. A
  wrong shadow decision stops qualification and someone looks at it. Those costs
  differ by orders of magnitude.

And one reason that makes shadow mode valuable rather than merely cautious: it
is how Seki earns trust at all.

### The trap: a circular shadow

A shadow comparison only produces independent evidence if the two sides are
independent.

If the Seki kernel is written by **reading the existing implementation**, the
two will agree — for months — because they encode the same reading of the
policy, including the same misunderstanding. The comparison would establish only
that Seki faithfully reproduces the incumbent's interpretation.

So the kernel should be written **from the policy specification**, by someone
who has not just read the existing branches. Then a disagreement means
something: one of two independent readings of the policy is wrong, and it is
worth finding out which.

With a Lean requirement in place, a project gets three independent readings of
one policy — the requirement, the kernel and the incumbent — and a disagreement
between any two of them is worth investigating.

### From shadow to authority

A project's own sequence distinguishes two things that are easy to run
together: *acting on* a decision, and a decision *carrying authority* for
publication. They need different evidence.

- To act on a Seki decision: a frozen boundary and accumulated field agreement.
- To let it carry authority: the proofs.

The freeze can unblock the first considerably sooner than the proofs can unblock
the second.

---

## 15. Assurance levels a project can choose

Not every project needs every layer. The layers separate cleanly:

| Level | What it adds |
| --- | --- |
| **Essential** | A Lean requirement, the exact kernel, a proof that it satisfies the requirement, and a proof that compilation preserves its meaning into a precisely defined C fragment |
| **Established C semantics** | That C fragment is defined by CompCert's Clight rather than by Seki, removing the one link whose trust cannot otherwise be borrowed |
| **Verified native code** | CompCert, rather than a trusted and recorded conventional compiler, produces the binary |
| **Independent double-checking** | Two separate proof foundations check the same invocation and must agree |

The first is what makes Seki worth using. The rest are genuine upgrades, each
with real cost, and should be chosen deliberately rather than assumed.

---

## 16. Where we are today

*This section describes the present. Everything above describes the target.*

### What exists

- **A working alpha compiler.** It turns the agreed subset into a canonical typed
  core, restricted C and a public header, deterministically.
- **A stable decision ABI.** Accept or reject; rejection tags authored in the
  source and never derived from declaration order; the failing premise; typed
  rejection detail; a byte-comparable layout zeroed before use, so two
  decisions identical in meaning compare equal byte for byte.
- **Structural rejection precedence.** When several premises would fail, the one
  reported follows the declared order, and a kernel that contradicts its own
  declared order does not compile.
- **A frozen host-boundary contract**, checked mechanically against what the
  compiler emits.
- **Reproducible, self-verifying bundles.** Compiler sources, kernel, typed core,
  generated C, header, tag dictionary and contract, bound by digest. The bundle
  rebuilds the compiler from the sources it carries and confirms it reproduces
  every artifact byte for byte.
- **One machine-checked Lean proof**, checked against a pinned toolchain by the
  project's verification suite, that a single example program satisfies its
  requirement.

### What does not exist yet

- **There is no verified compiler.** The working compiler is conventional and
  untrusted, and nothing yet proves that its C preserves the typed core's
  meaning.
- **No customer kernel can be checked against a Lean requirement.** The program
  proof exists only for the one example it was built for.
- **The one existing proof does not yet borrow only the kernel's trust.** It
  uses a Lean feature that relies on Lean's code generator rather than only its
  small kernel. That will be replaced.
- **Much of the alpha's testing is not independent.** It compares generated code
  against reference policies written by the same people who wrote the compiler.
  It is thorough, and it has found real defects, but it is the closed loop this
  document warns against, and it is weaker evidence than its volume suggests.

---

## 17. What changes as a result of this vision

The alpha was built before this picture was clear. Some of it will be reworked,
and we think that is the right trade.

The largest change is **order**. The work so far concentrated on producing
correct C, which is the compiler proof's territory. But the program proof is
what a customer buys, and it does not need the compiler proof at all: it proves
things about the typed core, which is the authority. So the order becomes:

1. **Decode and evaluate any kernel in Lean**, not one example.
2. **Let a project state a requirement in Lean and check its kernel against
   it.** This delivers the proposition.
3. **Use that Lean evaluator as the oracle for differential execution** of the
   generated C, replacing reference policies written by the compiler's authors.
   This makes the existing evidence independent.
4. **Remove every proof step that does not borrow only the kernel's trust.**
5. **Define `compile` in Lean, prove it correct once, and check the working
   compiler against it.** The working compiler becomes a fast, untrusted
   producer.
6. **Adopt CompCert's Clight semantics**, and optionally its native compiler,
   where a project needs that level.

Steps 1 and 2 deliver the proposition. Step 3 makes today's evidence honest.
Steps 4 to 6 are the long tail — and they are the part it is tempting to assume
is the whole job.

---

## 18. Questions we would like your view on

These are the points where your answer would change what we build. We are not
asking what features Seki should add; the surface is fixed. We are asking
whether the picture above is right for how you would actually use it.

1. **The proposition.** Is *"a small decision kernel as stable C, with
   independently checkable evidence of what it means"* the thing you need? If
   not, what is?

2. **Who writes the requirement.** Independent authorship only works if someone
   other than the kernel's author will state the requirement in Lean. In your
   organisation, who would that be? Would they? If nobody would, the program
   proof loses much of its value, and we would rather know now.

3. **Assurance level.** Which level in section 15 do you actually need, and for
   which decisions? In particular, is a trusted and recorded conventional C
   compiler acceptable, or do you need CompCert to produce the binary?

4. **Targets.** Evidence is relative to a named target and toolchain. Which
   processors, operating systems and compilers must Seki's evidence cover for
   you?

5. **The security property.** Do you depend, or expect to depend, on
   data-independent timing for identity comparison? If so it needs its own
   argument, and we should plan for one explicitly.

6. **The shadow period.** How long would you run a Seki kernel in shadow, and
   what would have to be true for you to let it act? For it to carry authority?

7. **The shape of your kernels.** If a decision you have in mind does not fit
   Seki's fixed surface, that is useful to us as information about whether Seki
   is the right tool for it, or whether the decision could be split so that a
   bounded kernel decides the part that carries authority. We would like to
   hear about those cases — not as requests, but as evidence about where the
   boundary should be.

8. **What we have wrong.** Anything in this document you think is mistaken,
   overclaimed or missing. We would rather redo work than build on a wrong
   picture.

---

## Glossary

**Kernel.** A single bounded decision function written in Seki: one record in,
one decision out.

**Typed core.** The canonical, checksum-bound binary encoding of a kernel's
meaning. The authority that every proof and every artifact is anchored to.

**Program proof.** A Lean proof that one specific kernel satisfies one stated
requirement, for every input.

**Compiler proof.** A Lean proof, made once, that compilation preserves every
kernel's meaning.

**Requirement.** A property stated in Lean, independently of any program, that a
kernel is required to satisfy.

**Clight.** A restricted C language, part of CompCert, with a formally defined
meaning.

**Shadow.** Running a Seki kernel beside an existing implementation, comparing
every decision, without letting Seki's decision take effect.

**Borrowed trust.** Assurance that comes from a tool the field already trusts,
used unmodified.

**Earned trust.** Assurance that comes from field agreement accumulated during a
shadow period.
