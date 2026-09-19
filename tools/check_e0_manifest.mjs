import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";

import { decodeModule } from "./encoding/decode_scb0.mjs";
import { checkTypedCore } from "./encoding/check_typed_core.mjs";

const manifestPath = "experiments/e0-vs1/MANIFEST.json";
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function checkFile(entry) {
  assert.notEqual(entry.path, manifestPath, "manifest must not digest itself");
  const bytes = fs.readFileSync(entry.path);
  assert.equal(bytes.length, entry.length, `${entry.path}: length changed`);
  assert.equal(sha256(bytes), entry.sha256, `${entry.path}: SHA-256 changed`);
}

assert.equal(manifest.schema, "io.frogfish.seki/experimental-vertical-slice-manifest@0");
assert.equal(manifest.experiment, "E0-VS1");
assert.equal(manifest.authority, "experimental-only");
assert.equal(manifest.self_identity, "intentionally-omitted-to-avoid-self-reference");

checkFile(manifest.artifacts.contract);
checkFile(manifest.artifacts.source);
checkFile(manifest.artifacts.lean_theorem);
checkFile(manifest.artifacts.generated_c);
checkFile(manifest.artifacts.trust_report);
checkFile(manifest.artifacts.closeout_review);
for (const entry of manifest.artifacts.implementation) checkFile(entry);
for (const entry of manifest.artifacts.evidence_programs) checkFile(entry);

const typedCoreEntry = manifest.artifacts.typed_core;
const encodedFile = fs.readFileSync(typedCoreEntry.path);
assert.equal(encodedFile.length, typedCoreEntry.encoded_file_length);
assert.equal(sha256(encodedFile), typedCoreEntry.encoded_file_sha256);
const hex = encodedFile.toString("ascii").trim();
assert.match(hex, /^(?:[0-9a-f]{2})+$/u, "SCB fixture is not canonical lowercase hex");
const typedCore = Buffer.from(hex, "hex");
assert.equal(typedCore.length, typedCoreEntry.decoded_length);
assert.equal(sha256(typedCore), typedCoreEntry.decoded_sha256);
const moduleDigest = createHash("sha256")
  .update(typedCoreEntry.digest_domain_ascii, "ascii")
  .update(Buffer.from(typedCoreEntry.digest_domain_terminator_hex, "hex"))
  .update(typedCore).digest("hex");
assert.equal(moduleDigest, typedCoreEntry.module_sha256);

const decoded = decodeModule(typedCore);
checkTypedCore(decoded);
const exact = decoded.kernels[0][1].exact;
assert.deepEqual(exact, Object.values(typedCoreEntry.exact_resource_bounds));

const contract = JSON.parse(fs.readFileSync(manifest.artifacts.contract.path, "utf8"));
assert.equal(contract.source.sha256, manifest.artifacts.source.sha256);
assert.equal(contract.typed_core.length, typedCoreEntry.decoded_length);
assert.equal(contract.typed_core.module_sha256, typedCoreEntry.module_sha256);
assert.equal(contract.policy.threshold, 18);

const leanSource = fs.readFileSync(manifest.artifacts.lean_theorem.path, "utf8");
assert.match(leanSource, /include_str "\.\.\/\.\.\/\.\.\/experiments\/e0-vs1\/minimum_age\.scb0\.hex"/u);
for (const theorem of manifest.artifacts.lean_theorem.decoded_program_theorems) {
  assert.match(leanSource, new RegExp(`theorem ${theorem}\\b`, "u"));
}
assert.doesNotMatch(leanSource, /\b(?:sorry|admit|axiom)\b/u);

const generatedC = fs.readFileSync(manifest.artifacts.generated_c.path, "utf8");
assert.match(generatedC, /applicant\.age < UINT8_C\(18\)/u);
assert.doesNotMatch(generatedC, /Copyright|GPL|runtime/u);

const trustReport = fs.readFileSync(manifest.artifacts.trust_report.path, "utf8");
assert.match(trustReport, /There is no theorem connecting the Lean semantics/u);
assert.match(trustReport, /CompCert 3\.18 was neither acquired nor invoked/u);
assert.match(trustReport, /does not support “Seki is proved,”/u);

const closeout = fs.readFileSync(manifest.artifacts.closeout_review.path, "utf8");
assert.match(closeout, /continue the architecture; do not expand the language surface yet/u);
assert.match(closeout, /Close E0-VS1 and resume at F0-01/u);

assert.equal(manifest.observed_environment.qualification_bound, false);
for (const value of Object.values(manifest.claims)) assert.equal(value, false);
assert.equal(manifest.evidence.admitted_input_values_executed, 256);
assert.equal(manifest.evidence.threshold_variant_executed, true);
assert.equal(manifest.evidence.address_sanitizer_executed, true);
assert.equal(manifest.evidence.undefined_behavior_sanitizer_executed, true);

const paths = [
  manifest.artifacts.contract.path,
  manifest.artifacts.source.path,
  typedCoreEntry.path,
  manifest.artifacts.lean_theorem.path,
  manifest.artifacts.generated_c.path,
  manifest.artifacts.trust_report.path,
  manifest.artifacts.closeout_review.path,
  ...manifest.artifacts.implementation.map(entry => entry.path),
  ...manifest.artifacts.evidence_programs.map(entry => entry.path),
];
assert.equal(new Set(paths).size, paths.length, "manifest contains duplicate artifact paths");
assert.equal(paths.includes(manifestPath), false, "manifest contains its own path");

console.log(
  `e0_manifest=verified artifacts=${paths.length} scb_bytes=${typedCore.length} ` +
  `scb_sha256=${moduleDigest} c_bytes=${manifest.artifacts.generated_c.length}`,
);
