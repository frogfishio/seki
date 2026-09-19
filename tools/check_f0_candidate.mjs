import assert from "node:assert/strict";
import fs from "node:fs";

const candidate = JSON.parse(fs.readFileSync("docs/f0/F0_CANDIDATE.json", "utf8"));
const packet = fs.readFileSync(candidate.packet, "utf8");
const project = JSON.parse(fs.readFileSync("PROJECT_STATUS.json", "utf8"));

assert.equal(candidate.schema, "io.frogfish.seki/f0-independent-candidate@0");
assert.equal(candidate.status, "candidate-selected-field-validation-deferred");
assert.equal(candidate.consumer, "Grit 3 Stage 1");
assert.equal(candidate.reviewer.role, "Grit Stage 1 authority-chain maintainer");
assert.equal(candidate.reviewer.identity, null);
assert.equal(candidate.reviewer.acceptance, null);
assert.equal(candidate.material_difference.customer_specific_core_primitive_required, false);
assert.equal(candidate.proposed_bounds.variable_length_collections, 0);
assert.equal(candidate.proposed_bounds.exact_costs_accepted, false);

assert.equal(project.active_work_package, "A0-02");
assert.equal(project.alpha_development_authorized, true);
assert.equal(project.alpha_claim_class, "provisional-bootstrap-alpha");
assert.equal(project.global_f0, "open");
assert.equal(project.independent_consumer_review,
  "deferred-until-field-validation");
assert.equal(project.field_validation_status,
  "deferred-until-release-candidate");
assert.equal(project.independent_consumer_candidate, candidate.decision_id);
assert.equal(project.independent_reviewer_identity, null);

assert.match(packet, /No acceptance is recorded yet/u);
assert.match(packet,
  /no review is\s+requested until a release candidate exists/u);
assert.match(packet, /a role is not a reviewer identity/u);
assert.match(packet, /G3-PACK-008/u);
assert.match(packet, /without Kiku, Arena, GCIR, Grit, grammar, or Gnosis/u);

const sourcePaths = candidate.source_observation.files.map(entry => entry.path);
assert.equal(new Set(sourcePaths).size, sourcePaths.length);
for (const entry of candidate.source_observation.files) {
  assert.match(entry.sha256, /^[0-9a-f]{64}$/u);
}
for (const value of Object.values(candidate.claims)) assert.equal(value, false);

console.log(
  `f0_candidate=verified consumer=${JSON.stringify(candidate.consumer)} ` +
  `decision=${candidate.decision_id} field_validation=deferred`,
);
