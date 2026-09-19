import fs from "node:fs";

const status = JSON.parse(fs.readFileSync("PROJECT_STATUS.json", "utf8"));
const plan = fs.readFileSync("docs/roadmap/DELIVERY_PLAN.md", "utf8");
const roadmapStatus = fs.readFileSync("docs/roadmap/STATUS.md", "utf8");
const expect = (condition, message) => {
  if (!condition) throw new Error(`Seki project status: ${message}`);
};

expect(status.schema === "io.frogfish.seki/project-status@1",
  "unknown status schema");
expect(status.language_identity === "io.frogfish.seki/language@0",
  "language identity drift");
expect(status.charter_revision === "0.3", "charter revision drift");
expect(status.delivery_plan_version === "0.3", "delivery plan version drift");
expect(status.current_stage === "B0", "unexpected current stage");
expect(status.active_work_package === "A0-02",
  "unexpected active work package");
expect(status.experimental_work_authorized === true,
  "completed bootstrap experiment lost its authorization record");
expect(status.experimental_work_status === "complete",
  "E0-VS1 must remain recorded as complete");
expect(status.alpha_track === "A0", "unexpected alpha track");
expect(status.alpha_development_authorized === true,
  "usable alpha development is not authorized");
expect(status.alpha_status === "active", "A0 must remain active");
expect(status.alpha_claim_class === "provisional-bootstrap-alpha",
  "alpha claim class drift");
expect(status.development_assurance_model === "internal-self-attestation",
  "development assurance model drift");
expect(status.internal_certification_status === "not-ready",
  "unfinished bootstrap cannot be internally certified");
expect(status.field_validation_status === "deferred-until-release-candidate",
  "field validation state drift");
expect(status.go_live_eligible === false,
  "project became live-eligible before field validation");
expect(status.formal_foundation_lock === "foundations/FOUNDATION_LOCK.json",
  "formal foundation lock path drift");
expect(status.formal_foundation_sources_bound === true,
  "formal foundation source identities are not bound");
expect(status.formal_foundations_installed === false,
  "installation must remain false until clean-room tools are recorded");
expect(status.formal_foundations_qualified === false,
  "foundation authority granted before qualification");
expect(status.compcert_acquisition_policy ===
  "user-supplied-no-full-redistribution",
  "CompCert acquisition policy drift");
expect(status.license === "GPL-3.0-or-later", "license drift");
expect(status.generated_artifact_policy === "customer-controlled",
  "generated-artifact policy drift");
expect(status.runtime_exception === "legal-text-pending",
  "runtime exception must remain pending until its exact text is adopted");

if (status.global_f0 === "open") {
  expect(status.independent_consumer_review ===
    "deferred-until-field-validation",
    "open F0 review must remain deferred until field validation");
  expect(status.independent_consumer_candidate ===
    "io.frogfish.grit/stage1-handoff-publication@candidate-1",
    "open F0 candidate selection drift");
  expect(status.independent_reviewer_role ===
    "Grit Stage 1 authority-chain maintainer",
    "open F0 reviewer role drift");
  expect(status.independent_reviewer_identity === null,
    "reviewer identity must remain empty until an accountable reviewer is named");
  expect(status.f1_implementation_authorized === false,
    "F1 cannot be authorized while global F0 is open");
  for (const claim of [
    "implementation_authority",
    "proof_authority",
    "native_binary_authority",
    "product_authority",
    "production_authority"
  ]) expect(status[claim] === false, `${claim} granted while F0 is open`);
} else {
  expect(status.global_f0 === "closed", "global_f0 must be open or closed");
}

expect(status.current_stage === "B0",
  "A0 and completed E0 evidence remain bootstrap work");
expect(status.f1_implementation_authorized === false,
  "completed E0-VS1 must not silently authorize F1");

expect(plan.includes(`Plan version: ${status.delivery_plan_version}`),
  "delivery plan and machine status disagree");
expect(plan.includes(`Current gate: global F0 ${status.global_f0}`),
  "delivery plan gate disagrees with machine status");
expect(roadmapStatus.includes(`Current stage: ${status.current_stage} bootstrap`),
  "roadmap status and machine stage disagree");
expect(roadmapStatus.includes(`Current gate: global F0 ${status.global_f0}`),
  "roadmap status and machine gate disagree");

console.log(
  `seki_project_status=verified global_f0=${status.global_f0} ` +
  `f1_authorized=${status.f1_implementation_authorized}`
);
