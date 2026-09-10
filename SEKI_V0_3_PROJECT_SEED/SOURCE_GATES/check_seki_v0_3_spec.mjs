import fs from "node:fs";

const spec = fs.readFileSync("docs/architecture/SEKI_V0_SPEC.md", "utf8");
const review = JSON.parse(fs.readFileSync(
  "docs/architecture/SEKI_V0_3_REVIEW.json", "utf8"));
const expect = (condition, message) => {
  if (!condition) throw new Error(`Seki-v0.3: ${message}`);
};

expect(review.schema === "io.frogfish.seki/spec-review@0.3" &&
  review.identity === "io.frogfish.seki/language@0" &&
  review.revision === "0.3", "identity or revision drift");
expect(review.f0_closed === false && review.authority_granted === false,
  "pre-freeze claim ceiling weakened");
expect(review.toolchain_foundations.lean === "4.30.0" &&
  review.toolchain_foundations.rocq === "9.2.0" &&
  review.toolchain_foundations.compcert === "3.18",
"foundation lock drift");

const bridge = review.cross_foundation_profile;
expect(bridge.certificate_short_name === "SSDC-1" &&
  bridge.scope === "one-concrete-authority-bearing-invocation",
"proof-carrying invocation identity drift");
expect(JSON.stringify(bridge.same_certificate_checked_by) === JSON.stringify([
  "qualified-lean-checker", "qualified-rocq-checker"
]), "joint checker inventory drift");
expect(JSON.stringify(bridge.acceptance_objects) === JSON.stringify([
  "LeanCertificateAcceptance", "RocqCertificateAcceptance", "JointCertificateReceipt"
]), "certificate acceptance object drift");
expect(bridge.joint_receipt_is_publication_premise === true &&
  bridge.boolean_acceptances_are_sufficient === false,
"joint receipt authority boundary weakened");
expect(bridge.universal_common_certificate_existence_claimed === false &&
  bridge.universal_lean_rocq_equality_claimed === false &&
  bridge.future_universal_profile_requires_common_witness_theorem === true &&
  bridge.independent_constructor_completeness_is_sufficient === false,
"universal bridge claim ceiling weakened");

expect(review.formal_c_foundation.rocq_to_clight_refinement_scope ===
  "universal-over-admitted-modules-and-inputs" &&
  review.formal_c_foundation.lean_to_rocq_refinement_scope ===
  "jointly-certified-invocation-only" &&
  review.formal_c_foundation.generated_c_to_normative_lean_scope ===
  "jointly-certified-invocation-only" &&
  review.formal_c_foundation.joint_receipt_absent_lean_equivalence_claimed === false &&
  review.formal_c_foundation.joint_receipt_absent_authority_publication_count === 0,
"refinement scope conflated");
expect(review.publication_protocol.certificate_validation_precedes_committable_candidate === true &&
  review.publication_protocol.missing_or_mismatched_certificate_publication_count === 0,
"certificate-gated publication weakened");
expect(JSON.stringify(review.qualification_stages) === JSON.stringify([
  "F0", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"
]), "qualification ladder drift");

const paths = [
  "section-17/proof-carrying-invocation",
  "section-17/joint-certificate-receipt",
  "section-20/certificate-gated-publication",
  "section-23/v0-claim-ceiling",
  "section-23/F4/refinement-scope"
];
expect(JSON.stringify(review.confirmation_paths) === JSON.stringify(paths),
  "confirmation path inventory drift");
for (const phrase of [
  "Status: v0.3 design revision",
  "Seki v0.3 adopts proof-carrying invocation",
  "For each concrete authority-bearing",
  "LeanCertificateAcceptance",
  "RocqCertificateAcceptance",
  "JointCertificateReceipt",
  "Seki v0 makes no claim that one common",
  "completeness of two constructors is insufficient",
  "certificate must receive both qualified checker",
  "generated Clight behavior",
  "equals the Rocq Seki relation",
  "This universal theorem does not mention or imply the normative Lean",
  "derive generated-C-to-Lean equality only for that jointly certified",
  "Without the exact joint certificate receipt, no Lean-equivalence claim",
  "accepted_seki_v0_3_for_f0",
  "seki_v0_3_revision_ready_for_f0_review"
]) expect(spec.includes(phrase), `normative specification omits: ${phrase}`);
for (const path of paths) expect(spec.includes(path), `spec omits confirmation path ${path}`);

const f4 = spec.slice(spec.indexOf("### F4 — Generator refinement"),
  spec.indexOf("### F5 — Toolchain and artifact closure"));
expect(!f4.includes("restricted-C evaluation equals Seki evaluation for every"),
  "F4 restored an ambiguous universal C-to-Lean/Seki claim");
expect(f4.includes("generated Clight behavior") &&
  f4.includes("Rocq Seki relation") &&
  f4.includes("jointly certified") &&
  f4.includes("no Lean-equivalence claim"),
"F4 does not separate universal Rocq and invocation-scoped Lean relations");

console.log("seki_v0_3_spec=verified f0=open bridge=proof-carrying-invocation authority=none");
