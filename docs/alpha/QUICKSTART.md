# Seki quickstart

You have a decision to make, it is small and bounded, and you want the code
that makes it to be generated from something you can read rather than written
by hand. That is what Seki is for.

This gets you from nothing to a compiled kernel you can call from C. It assumes
you have a C11 compiler and nothing else.

Read [`HOST_BOUNDARY_CONTRACT.md`](HOST_BOUNDARY_CONTRACT.md) before you
integrate. It is short, and it states what a kernel does not do.

## 1. Build the compiler

```sh
make alpha
```

That produces `build/sekic`. There is nothing to install.

## 2. Write a kernel

A kernel takes one record and returns a decision. Here is a complete one.

```seki
module example::gate @ 1
profile: c11_bounded @ 1
claims: semantic_evaluation
requires: totality.

export nominal AccountId := Digest[sha256, 32].

export record Request {
  account: AccountId,
  boundAccount: AccountId,
  age: U8,
  tier: U16
}.

export variant Denial [
  UnknownAccount @ 1.
  Underage @ 2.
  TierTooLow(limit: U16, actual: U16) @ 5.
].

export kernel authorise request: Request
-> Decision[Unit, Denial]
arithmetic: checked
bounded steps: 256 liveBits: 8192 controlDepth: 64 workspaceBits: 0
rejects: Denial::UnknownAccount, Denial::Underage, Denial::TierTooLow
publication: none [
  account := request account.
  require account == (request boundAccount) else: Denial::UnknownAccount.
  require (request age) >= 18 else: Denial::Underage.
  require (request tier) >= 100
    else: Denial::TierTooLow(limit: 100, actual: (request tier)).
  accept unit
].
```

Line by line:

- **`module … @ 1`** — the module's path and version. `profile:` selects the
  semantic profile; `c11_bounded @ 1` is the only one. `claims:` and
  `requires:` state what the module claims and what theorem obligations it
  carries. `semantic_evaluation` and `totality` are the usual minimum.
- **`nominal AccountId := Digest[sha256, 32]`** — a distinct type that happens
  to be 32 octets. A second nominal over the same representation will not
  compare with this one. That is the point: you cannot pass a device identity
  where an account identity is required. Use `type` instead of `nominal` for a
  transparent synonym.
- **`record Request`** — the kernel's single input. Field order in the source
  is free; the compiler orders everything canonically.
- **`variant Denial`** — the rejection reasons. Each carries an explicit stable
  tag after `@`. **The tag is yours, not the compiler's** — it never comes from
  declaration order, so reordering the declarations cannot change what your
  caller sees. Tag `0` is reserved and means "no rejection". A case may declare
  a payload in parentheses.
- **`rejects:`** — the precedence order. When several premises would fail, the
  earliest in this list is the one reported. The body must check premises in
  this order, and will not compile otherwise.
- **`bounded steps: … liveBits: … controlDepth: … workspaceBits: …`** — your
  declared ceilings, in the order steps, live bits, control depth, workspace
  bits. The compiler derives the exact cost and rejects a ceiling below it.
  Start generous, then read the real figures with `sekic inspect`:

  ```text
  exact_bounds=38,2640,11,0
  declared_ceiling=512,16384,64,0
  ```
- **`account := request account.`** — an immutable binding. Its scope is the
  rest of the body. It cannot shadow anything visible.
- **`require C else: Denial::Case.`** — one premise and the rejection that
  reports its failure. This is the form you will use most.
- **`accept unit`** — the decision. `Unit` means acceptance carries no value;
  see section 6 for the alternative.

## 3. Compile it

```sh
build/sekic check gate.seki
build/sekic build --core gate.scb0 --c gate.c --header seki_a0_gate.h gate.seki
```

`check` validates. `build` additionally writes the typed core, the C, and the
public header. **If any stage fails, no file is written at all** — there is no
partial output to clean up.

`--header` is optional. Without it the C is self-contained; with it the
declarations move to the header and the C includes it.

## 4. Call it

```c
#include "seki_a0_gate.h"

seki_a0_gate_request request = {0};
/* fill every field: the kernel reads whatever it is given, and an
   uninitialised field is an unspecified decision, not a rejection */

seki_a0_gate_decision d = seki_a0_gate_authorise(request);

if (d.disposition == 1U) {
    /* accepted */
} else {
    /* d.rejection_tag is 1, 2 or 5 — the tags you declared */
    /* d.premise_tag is which premise failed, one-based */
    if (d.rejection_tag == 5U) {
        uint16_t saw = d.rejection.tiertoolow.seki_f_actual;
        uint16_t wanted = d.rejection.tiertoolow.seki_f_limit;
    }
}
```

Compile `gate.c` with your project. It needs only `<stdint.h>`: no allocation,
no recursion, no unbounded loops, no libc.

Read `d.abi_revision` first if you keep decisions across builds. It rotates
whenever the layout changes.

## 5. What you can write in a body

| Form | Example |
| --- | --- |
| binding | `tier := request tier.` |
| field projection | `(request age)` |
| comparison | `== != < <= > >=` on integers; `==` `!=` on identities |
| Boolean | `a && b`, `a \|\| b`; `&&` binds tighter |
| premise | `require C else: V::Case.` |
| conditional | `C ifTrue: [ … ] ifFalse: [ … ]` |
| match | `match (request op) [ Case: [ … ]. … ]` |
| record literal | `Permit { epoch: e, tier: t }` |
| decision | `accept <value>` / `reject V::Case` |

Identity comparison on `Bytes` and `Digest` lowers to a comparison whose
running time does not depend on where the first differing octet is.

## 6. Accepting a value

Acceptance can carry a record rather than `Unit`:

```seki
export record Permit { grantedTier: U16 }.

export kernel authorise request: Request
-> Decision[Permit, Denial]
…
  accept Permit { grantedTier: (request tier) }
```

The decision then has an `accepted` member of that type.

## 7. When it rejects your kernel

Diagnostics are `A0-<STAGE>-<NNNN>` and always name a stage. The ones you are
most likely to meet:

| Code | Means |
| --- | --- |
| `A0-CHECK-0004` | comparison operands do not have the same type. Two different nominals do not compare, and that is deliberate |
| `A0-CHECK-0008` | you rejected with a case that is not in `rejects:` |
| `A0-CHECK-0017` | a declared ceiling is below the derived exact cost. Raise it |
| `A0-CHECK-0019` | a binding shadows a visible local |
| `A0-CHECK-0021` | a record literal does not fill every field exactly once |
| `A0-CHECK-0023` | premises are checked in a different order than `rejects:` declares |
| `A0-CHECK-0024` | a rejection payload does not fill every declared field |
| `A0-CHECK-0027` | match arms do not cover every case exactly once |
| `A0-CHECK-0028` | you matched a payload-bearing case. Binders are not in this revision |
| `A0-PARSE-0035` | syntax nested deeper than the profile admits |
| `A0-PARSE-0039` | a variant case used stable tag `0`, which is reserved |
| `A0-LEX-0001` | an integer literal above `4294967295`. Source literals are `U32` |

An `A0-BACKEND-*` code means the typed core is valid but falls outside what
this revision projects to C.

## 8. What Seki deliberately does not have

No functions, arrays or traversal, `Option`/`Result`/`Tuple`, imports,
multi-module, generics, type inference, mutation, recursion, unbounded loops,
floating point, or effects. One kernel per module.

These are not gaps. A kernel that cannot loop, allocate or call out is a kernel
whose cost is derivable and whose behaviour is total.

## 9. Shipping it

```sh
make bundle KERNEL=gate.seki
```

This assembles a bundle containing the compiler sources that produced your
artifacts, the kernel source, typed core, generated C and header, the tag
dictionary, the host-boundary contract, and a manifest binding every file by
SHA-256. Its `VERIFY.sh` checks the digests, rebuilds the compiler from the
carried sources, confirms the rebuild reproduces the artifacts byte for byte,
and compiles the kernel.

Assembling the same inputs twice produces the same manifest digest.

## 10. What this is not

This is a provisional alpha. The syntax and the binary encoding are not frozen.

**The generated C is not proved to preserve your kernel's semantics.** That
refinement proof is the main open work. What backs the compiler today is a
second independent implementation that re-decodes every module it emits and
re-derives the resource bounds from scratch, exhaustive comparison of generated
kernels against their stated policy, differential execution against a Lean
evaluator of the exact typed-core bytes, and mutation fuzzing under
AddressSanitizer and UndefinedBehaviorSanitizer.

Use `sekic 0.0.0-alpha.7` or later. Revision `0.0.0-alpha.6` compared and
copied a `Bytes[N]` or `Digest` value whose type was written directly, rather
than through a `nominal` or `type` declaration, as zero octets: two different
values compared equal, and a copy wrote nothing. Values of a declared type,
such as a `nominal AccountId`, were not affected.

That is real engineering evidence. It is not a proof, and nothing here should
be treated as carrying implementation, proof, product or production authority.
