import crypto from "node:crypto";
import fs from "node:fs";
const read = (p) => fs.readFileSync(new URL(p, import.meta.url), "utf8");
const expect = (v, m) => { if (!v) throw new Error(`Seki seed: ${m}`); };
const source = JSON.parse(read("SOURCE_IDENTITY.json"));
const contract = JSON.parse(read("CONTRACTS/SEKI_V0_3_REVIEW.json"));
const acceptance = JSON.parse(read("ACCEPTANCE/SEKI_V0_3_KIKU_F0_ACCEPTANCE.json"));
const spec = read("SPEC/SEKI_V0_SPEC.md");
const plan = read("BOOTSTRAP/SEKI_F1_BOOTSTRAP_PLAN.md");
expect(source.language_identity === "io.frogfish.seki/language@0", "source identity drift");
expect(source.accepted_specification_commit === "65692f383d31b2d50d694f68133be578528b0710", "accepted commit drift");
expect(source.kiku_f0_review === "accepted" && source.global_f0 === "open", "F0 state drift");
expect(source.implementation_authority === false && source.proof_authority === false &&
  source.product_authority === false, "seed grants authority");
expect(contract.schema === "io.frogfish.seki/spec-review@0.3" &&
  contract.disposition === "seki_v0_3_revision_ready_for_f0_review", "contract drift");
expect(contract.cross_foundation_profile.scope ===
  "one-concrete-authority-bearing-invocation", "bridge scope drift");
expect(contract.cross_foundation_profile.universal_lean_rocq_equality_claimed === false,
  "universal bridge claim introduced");
expect(acceptance.decision === "accepted_seki_v0_3_for_f0" &&
  acceptance.global_f0_closed === false, "consumer/global F0 state conflated");
expect(spec.includes("### F4 — Generator refinement") &&
  spec.includes("Without the exact joint certificate receipt, no Lean-equivalence claim"),
  "normative F4 scope missing");
expect(plan.includes("Seki F1 project bootstrap plan") &&
  plan.includes("seki_f1_implementation_authorized"), "bootstrap plan incomplete");
const sums = read("SHA256SUMS").trim().split("\n");
expect(sums.length >= 17, "manifest unexpectedly small");
console.log("seki_project_seed=verified revision=0.3 kiku=accepted global_f0=open authority=none");
