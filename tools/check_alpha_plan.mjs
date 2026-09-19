import fs from "node:fs";

const alpha = JSON.parse(fs.readFileSync("alpha/ALPHA_PLAN.json", "utf8"));
const status = JSON.parse(fs.readFileSync("PROJECT_STATUS.json", "utf8"));
const scope = fs.readFileSync("docs/alpha/A0_SCOPE.md", "utf8");
const adr = fs.readFileSync(
  "docs/decisions/0021-build-usable-alpha-before-f0-review.md", "utf8");

const expect = (condition, message) => {
  if (!condition) throw new Error(`Seki alpha plan: ${message}`);
};

expect(alpha.schema === "io.frogfish.seki/alpha-plan@1", "unknown schema");
expect(alpha.track === "A0" && alpha.status === "active", "A0 is not active");
expect(alpha.current_work_package === status.active_work_package,
  "alpha and project active work packages disagree");
expect(alpha.claim_class === "provisional-bootstrap-alpha",
  "alpha claim class drift");
expect(alpha.f0_may_remain_open === true && status.global_f0 === "open",
  "A0 must not silently close F0");
expect(alpha.f1_authorized === false && status.f1_implementation_authorized === false,
  "A0 must not authorize F1");
expect(alpha.language_frozen === false && alpha.encoding_frozen === false,
  "A0 must not freeze provisional interfaces");
expect(alpha.authority_granted === false, "A0 granted authority");
expect(alpha.development_assurance_model === "internal-self-attestation",
  "development assurance model drift");
expect(alpha.internal_certification_target === "release-candidate",
  "internal certification target drift");
expect(alpha.field_validation_before_live === true,
  "field validation is not required before live use");
expect(alpha.field_validation_projects.join(",") === "Gnosis,Kiku,Grit",
  "field-validation project set drift");
expect(status.development_assurance_model === "internal-self-attestation",
  "project status lost internal assurance model");
expect(status.internal_certification_status === "not-ready",
  "unfinished A0 cannot be internally certified");
expect(status.field_validation_status === "deferred-until-release-candidate",
  "field validation started before the release candidate");
expect(status.go_live_eligible === false, "unfinished A0 became live-eligible");
expect(alpha.required_examples.join(",") ===
  "minimum-age,grit-stage1-publication", "required example drift");

const packages = alpha.work_packages;
expect(Array.isArray(packages) && packages.length === 10,
  "unexpected work-package ledger");
expect(packages.map((item) => item.id).join(",") ===
  "A0-01,A0-02,A0-03,A0-04,A0-05,A0-06,A0-07,A0-08,A0-09,A0-10",
  "work-package order drift");
expect(packages.filter((item) => item.state === "active").length === 1,
  "exactly one alpha work package must be active");
expect(packages.find((item) => item.state === "active")?.id ===
  alpha.current_work_package, "active package ledger mismatch");

for (const forbidden of [
  "implementation_authority", "proof_authority", "native_binary_authority",
  "product_authority", "production_authority"
]) expect(status[forbidden] === false, `${forbidden} granted during A0`);

expect(scope.includes("A0 completion alone does not close F0, authorize F1"),
  "scope lost its gate boundary");
expect(adr.includes("The solution is not to weaken F0"),
  "decision rationale drift");

console.log(
  `seki_alpha_plan=verified status=${alpha.status} ` +
  `work_package=${alpha.current_work_package} authority=false`
);
