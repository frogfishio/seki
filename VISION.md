# Seki: vision

## The proposition

A customer can receive a small decision kernel as ordinary, stable C, together
with independently checkable evidence of exactly what that kernel means,
without adopting or trusting a large language ecosystem.

Dafny helps you develop verified software. Seki lets you ship a small,
checksum-bound, proof-carrying decision as portable C.

## The problem

Critical systems are full of small decisions: may this artifact be published,
is this applicant eligible, is this operation authorised. They are usually
handwritten branches. Their correctness rests on tests, and tests sample:

```text
selected inputs  →  black box  →  observed outputs
```

If the chosen outputs match, you have evidence about the chosen inputs. The
untested ones, and any undefined behaviour or environmental effect, stay
hidden. A black box can be garbage and pass its tests.

Seki replaces sampling with reasoning over meaning:

```text
every admitted input  →  formally defined program meaning  →  theorem
```

This does not make a kernel correct. It moves the question from "did we test
enough cases?" to "did we state the right requirement?" — which is a better
question, because a requirement can be read and argued about, and a test suite
cannot tell you what it failed to cover.

## How it works: two proofs

A kernel's assurance rests on two separate claims.

```text
P satisfies the requirement R            the program proof
              +
compilation preserves P's meaning        the compiler proof
              =
the generated C satisfies R
```

**The program proof** is what the customer buys. A requirement is stated in
Lean, independently of any program:

```lean
def SafePolicy (f : Applicant → Decision) : Prop :=
  ∀ a, a.age < 18 → f a ≠ .approve
```

The exact kernel is decoded into Lean from its canonical bytes, never
transcribed by hand, and Lean checks the requirement against that program's
meaning:

```lean
theorem kernel_is_safe : SafePolicy (Seki.eval P)
```

**The compiler proof** is proved once, for every program:

```lean
theorem compile_correct : ∀ P x, C.exec (compile P) x = Seki.eval P x
```

Together they give `SafePolicy (C.exec (compile P))`: the generated C
satisfies the requirement, for every input, without that C ever having been
reasoned about directly.

The two are independent. Proving the compiler does not prove any program good,
and proving a program good says nothing about what was emitted. A kernel needs
both.

## Independent authorship

The requirement and the kernel should be written by different hands.

```text
Policy owner          →  the Lean requirement
Implementation author →  the Seki kernel
Lean                  →  referees their agreement
```

If they disagree, the proof fails. That is the point: the requirement and the
implementation are two independent readings of one intent, and Lean is a
strict referee between them rather than a participant.

The failure this guards against is the oldest one in formal methods. *What the
thinker thinks, the prover proves.* A team that writes the semantics, the
compiler and the proof has built a closed loop, and the proof will confirm what
they already believed. Separate authorship breaks the loop at the level that
matters most, which is intent.

Examples still have a job. They test the requirement itself — whether it
captures what anyone meant — and every requirement should carry a companion
that makes it falsifiable, so it cannot be satisfied vacuously. A requirement
that "no minor is approved" is also met by a kernel that approves no one.

## Trust

Proof is not the same as trust. An incumbent that has run in production
without failing is proven empirically, and that is real evidence. A new system
carrying proofs its authors wrote about themselves is not yet trusted, however
many proofs it carries.

So every part of Seki's assurance is either **borrowed** or **earned**.
Nothing is self-certified.

- **Borrowed**, from tools the field already trusts, used unmodified: Lean's
  kernel checks every proof, and CompCert where machine-level closure matters.
  Their trust comes from everyone else who has staked something on them. The
  moment Seki adds an axiom, patches a toolchain, or reaches around the kernel,
  it stops borrowing and starts self-certifying.
- **Earned**, in the field: by running beside an incumbent as a shadow and
  comparing every decision, until disagreements have been investigated and
  agreement has accumulated.

A shadow period is not a stage to get through. It is one of only two sources of
trust available at all.

## The chain, and what each link rests on

```text
Seki source text
    │  parser and elaborator            untrusted; not the authority
    ▼
canonical typed core                    THE AUTHORITY
    │  Seki.eval, defined in Lean       our definition; kept small and legible
    ▼
decision function
    │  compile, proved once in Lean     borrowed: Lean kernel
    ▼
restricted C
    │  C compiler                       trusted and recorded, or CompCert
    ▼
machine code
    │  silicon                          a physical limit; evidenced by execution
    ▼
decision
```

**The compiler that actually runs stays untrusted.** `sekic` may be fast,
convenient and handwritten. The verified `compile` function in Lean is the
authority, and Lean's kernel checks that `sekic`'s output equals it by
reduction. A bug in `sekic` then produces a rejected artifact, not a plausible
kernel that decides wrong.

**The typed core, not the source text, is the root.** Lean proves things about
the canonical bytes. The elaborator that produced them is untrusted and does
not need to be proved; it only needs to produce a core that is then decoded,
checked and bound by digest.

**The restricted-C semantics is ours.** It is the one link whose trust cannot
be borrowed, so it is kept as small as possible — the emitted language has no
floating point, no undefined arithmetic, no allocation, no recursion, and three
fixed bounded loops — and it is checked against execution rather than taken as
definitional.

**Evidence is complete along different axes.** A proof covers every input but
only down to a model. Execution covers the whole stack, including the actual
silicon, but only the inputs run. They cover each other's blind spots:

| | Inputs | Stack |
| --- | --- | --- |
| Lean proof | all | down to the C semantics |
| CompCert | all | C semantics to a machine model |
| Differential execution | those run | everything, including hardware |

For a kernel with a small input domain, execution can be exhaustive, and then
nothing is left to wonder about for that kernel, on that target, with that
compiler.

## There is a physical limit

No chain reaches the machine. CompCert is proved to a model of the
instruction set; the model is not the silicon, and silicon ships with errata.

That limit is real but small. Specification error is neither, and it is where
formal methods actually fail: the proof is valid, the theorem is true, and the
theorem is about something other than what was shipped. Seki's defences against
it are independent authorship, falsifiable requirements, and execution on the
real target — not more proof.

So Seki never claims "verified". Its claim has a shape: *proved relative to a
stated model, and executed on a named target with a named toolchain.* The
target and toolchain are part of the evidence, not context.

## What Seki deliberately is not

Seki is not a general-purpose language. It has no functions, arrays or
traversal, no `Option` or `Result`, no imports, generics, type inference,
mutation, recursion, unbounded loops, floating point or effects. One kernel per
module.

These are not gaps. A kernel that cannot loop, allocate or call out is a kernel
whose cost is derivable, whose behaviour is total, and whose meaning is small
enough to reason about completely. Every omitted feature is a class of
reasoning nobody has to do. The surface is fixed by agreement, not grown by
request.

Seki does not authenticate anything. A kernel consumes identities the host has
already authenticated and decides only whether they stand in the relationships
its policy requires. Authority for authentication rests with the host.

## Where we are

This section describes the present. Everything above describes the target.

**True today:**

- A compiler, `sekic`, that turns the agreed alpha subset into a canonical
  typed core, restricted C, and a public header, deterministically.
- A stable decision ABI with authored rejection tags, deterministic precedence,
  typed payloads, and a byte-comparable layout.
- A frozen host-boundary contract.
- Reproducible, self-verifying consumer bundles.
- An independent second implementation that re-decodes every emitted core and
  re-derives its resource bounds, exhaustive and differential testing, and
  mutation fuzzing under sanitizers.
- A Lean proof, checked on every build against the pinned toolchain, that
  **one** hardcoded program satisfies its requirement.

**Not true today:**

- There is no verified compiler. `sekic` is handwritten and untrusted, and
  nothing proves that its C preserves the typed core's meaning.
- No customer kernel can yet be checked against a Lean requirement. The program
  proof exists only for the one fixture it was built for.
- The existing Lean proof rests on `native_decide`, which trusts Lean's code
  generator rather than only its kernel. It does not yet borrow the trust this
  document relies on.
- Much of today's testing compares generated C against reference policies
  written by the same hands that wrote the compiler. It is thinker and prover in
  one head, and weaker evidence than its volume suggests.

**Next, in order:**

1. Decode and evaluate any admitted kernel's typed core in Lean, not one
   fixture.
2. Let a customer state a requirement in Lean and check their kernel against
   it. This is the product, and it proves things about the authority without
   needing the compiler proof at all.
3. Use that Lean evaluator as the oracle for differential execution of the
   generated C, replacing hand-written reference policies.
4. Remove `native_decide`, so every proof borrows only the kernel's trust.
5. Write `compile` in Lean, prove it correct once, and check `sekic` against
   it.
6. Bring in CompCert where machine-level closure, and the independence of a
   semantics nobody here wrote, is worth its cost.

Steps 1 and 2 deliver the proposition. Step 3 makes today's evidence honest.
Steps 4 to 6 are the long tail, and they are the part everyone assumes is the
whole job.
