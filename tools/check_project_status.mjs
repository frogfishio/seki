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
expect(status.delivery_plan_version === "0.1", "delivery plan version drift");
expect(status.current_stage === "B0", "unexpected current stage");
expect(status.active_work_package === null,
  "machine status names active work not reflected by this bootstrap gate");
expect(status.license === "GPL-3.0-or-later", "license drift");
expect(status.generated_artifact_policy === "customer-controlled",
  "generated-artifact policy drift");
expect(status.runtime_exception === "legal-text-pending",
  "runtime exception must remain pending until its exact text is adopted");

if (status.global_f0 === "open") {
  expect(status.independent_consumer_review === "pending",
    "open F0 requires a pending independent-consumer review");
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
