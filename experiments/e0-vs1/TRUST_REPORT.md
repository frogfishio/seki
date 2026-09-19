# E0-VS1 experimental trust report

- Status: complete experimental accounting; no qualification authority
- Date: 2026-09-19
- Manifest: `MANIFEST.json`
- Governing decision: `docs/decisions/0020-experimental-end-to-end-vertical-slice.md`

## 1. Result

E0-VS1 demonstrates that the proposed Seki architecture can be made concrete
on one complete bounded decision. Exact source regenerates exact typed-core
bytes. Lean decodes those bytes and checks the independently stated complete
threshold policy. A separate C backend reopens the bytes, emits deterministic
C11, and the resulting native kernel returns the required result for every one
of the 256 admitted inputs.

That is useful feasibility evidence. It is not a certified compiler result.
There is no theorem connecting the Lean semantics to the restricted-C AST, C
source, or native executable. Every project authority field remains false.

## 2. Arrow accounting

| Arrow or assertion | Evidence obtained | What remains unproved or external |
| --- | --- | --- |
| Human policy → Seki source | The full two-sided threshold policy, schema, and five boundary observations are recorded separately from the compiler. | A human can still specify the wrong policy or transcribe the requirement incorrectly. Seki does not prove legal, ethical, or business suitability. |
| Source bytes → parsed and checked program | The strict-C11 closed-subset frontend rejects six hostile mutations and accepts the fixed source. | The lexer, parser, shape checks, and diagnostics are handwritten and unproved. The parser recognizes one experiment, not the general candidate language. |
| Checked source program → SCB-0 bytes | Two runs are identical; C and independent JavaScript emitters agree on all 417 bytes; a threshold mutation changes the encoded literal. | There is no proof that the frontend preserves source semantics or always emits canonical typed core. SCB-0 remains provisional. |
| SCB-0 bytes → typed-core interpretation | Generic JavaScript checking, the fixture-bounded Lean decoder, and the independent C backend reopen the artifact. | None of the decoders is qualified. The Lean and C decoders are deliberately limited to this slice; agreement can share a specification mistake. |
| Decoded program → Lean policy | Lean checks `decoded_program_satisfies_policy`, `decoded_program_noMinorApproved`, and `decoded_program_adultApproved` against the included exact SCB hex. | The planned Lean foundation is unbound. The run used Lean 4.33.1 rather than planned 4.30.0 and uses `native_decide`, adding Lean native compilation and evaluation to the experimental trust base. |
| SCB-0 bytes → restricted-C AST | A separate C process validates the complete closed-slice module and constructs explicit condition and decision nodes. Three structural mutations reject without producing C. | The decoder and projection are handwritten and unproved. The AST exists only as experimental C structures and has no frozen schema, independent parser, or Clight embedding. |
| Restricted-C AST → exact C bytes | Repeated printing reproduces the recorded 524-byte translation unit and its raw SHA-256 identity. | The printer is handwritten and unproved. Print/parse AST correspondence has not been established. Identifier, ABI, header, and profile rules are not frozen. |
| Generated C → intended result | Strict C11 compilation succeeds. Native comparison covers all ages `0..255`; the threshold-19 variant also covers its whole input domain. ASan and UBSan report no failure in the exercised run. | Tests and sanitizers do not prove absence of undefined behavior. There is no CompCert/Clight refinement or proof that arbitrary conforming C implementations preserve the Seki result. |
| C bytes → native executable | Apple clang compiled and linked the test translation unit, which executed successfully on the observed Darwin arm64 host. | The compiler, assembler, linker, C headers, loader, CPU, and OS are trusted for this observation. The executable has no recorded identity and carries no native-binary authority. |
| Seki resource tuple → C resource use | The SCB decoder confirms exact Seki bounds `(8,25,5,0)`. | Those bounds describe the experimental Seki evaluator, not C instructions, stack layout, ABI objects, compiler resource use, or wall-clock time. |
| Host values → `Applicant` and result → consumer | The test harness constructs every `uint8_t` age and inspects both result bytes. | Real adapters, validation, calendars, jurisdictions, persistence, concurrency, and downstream interpretation are outside the experiment. |

## 3. Trusted and observed components

The experiment depends on these components for evidence, without qualifying
them or elevating them into proof authority:

- the human review of the policy, schema, source, theorem statement, and this
  trust report;
- the handwritten C frontend and backend, their bounded file I/O, and their
  diagnostic behavior;
- Node.js 26.7.0, its filesystem/process/Buffer APIs and SHA-256 implementation,
  plus the JavaScript SCB decoder and type checker;
- Lean 4.33.1 at commit
  `819816b2e0a3bf405af45ae5c7af2491d8f5bee6`, its kernel, elaborator,
  `include_str`, `native_decide`, native compiler path, and runtime;
- Apple clang 17.0.0, the assembler, linker, `<stdint.h>`, sanitizer runtimes,
  loader, Darwin 24.5.0 arm64 kernel, and processor;
- the repository filesystem preserving the bytes named by the manifest; and
- the correctness and collision resistance assumptions of SHA-256 where a
  digest stands in for direct byte comparison.

The manifest records observations, not pinned qualification identities. A
future tool with the same command name is not thereby the same trusted input.

## 4. Known discrepancies and limitations

1. The planned Lean 4.30.0 foundation is not bound; the experiment ran with
   Lean 4.33.1.
2. The initial qualification platform is Linux x86-64; this experiment ran on
   Darwin arm64.
3. Only Apple clang was exercised. GCC/Clang differential compilation and
   pinned optimization-level comparisons remain future work.
4. CompCert 3.18 was neither acquired nor invoked. There is no Rocq model,
   Clight embedding, or generated-C refinement theorem.
5. SCB-0, the source syntax, diagnostics, restricted-C AST, printer, ABI, and
   tag layout are provisional and cannot freeze conformance while F0 is open.
6. The source frontend and C backend are deliberately specialized to one
   module shape. Their rejection of other programs says nothing about the
   eventual Seki language.
7. The native test is exhaustive over the admitted `U8` input domain but still
   observes one compiled program through an unqualified harness and platform.
8. Sanitizers provide dynamic evidence only and can miss defects or contain
   defects themselves.
9. Output writes are not transactional; an I/O failure after opening an output
   path can leave a partial file. Parse and structural rejections create none.
10. The generated C contains no intended Seki runtime or library material, but
    this experiment is not a legal determination about copyrightability or the
    still-pending runtime exception.
11. No production adapter, stable ABI, installed binary, package, release, or
    customer deployment was built or authorized.

## 5. Claim ceiling

E0-VS1 supports only this statement:

> On the recorded local environment, the exact experimental source reproducibly
> produced the recorded SCB-0 and generated C artifacts; Lean checked the stated
> property of its decoded SCB program; and native execution of the generated C
> agreed with the policy across the complete admitted `U8` input domain.

It does not support “Seki is proved,” “the compiler is certified,” “the
generated C is verified,” “the native binary is correct,” or “the policy is
appropriate.” Closing those claims requires the later frozen foundations,
independent consumer gate, Rocq/Clight refinement, qualified toolchains, and
invocation-scoped certificate path described by the delivery plan.

## 6. E0-09 conclusion

The experiment exposed no architectural contradiction. In particular, the
exact typed-core artifact can serve both as the object of the Lean property and
as the independent input to C construction. The unresolved proof gap is now
visible rather than implicit: it is the refinement from admitted typed core to
restricted-C/Clight behavior, followed by the separately scoped native-toolchain
trust problem.

E0-10 should decide whether this evidence justifies expanding beyond the closed
slice, redesigning an interface, or stopping. That review must not convert the
experiment into F1 authority while global F0 remains open.
