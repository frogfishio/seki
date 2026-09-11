// Experimental semantic hostile checks over independently decoded SCB-0 objects.
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import { AdmissionError, decodeBundle, decodeModule } from "./decode_scb0.mjs";
import { checkTypedCore } from "./check_typed_core.mjs";

const emit = (name, mode) => execFileSync(process.execPath,
  [`tools/encoding/${name}`, ...(mode ? [mode] : [])]);
const minimalBytes = emit("emit_minimal_scb0.mjs");
const candidateBytes = emit("emit_candidate_selection_scb0.mjs");
const bundleBytes = emit("emit_import_bundle_scb0.mjs", "--bundle");
const payloadBytes = emit("emit_payload_records_scb0.mjs");
const arithmeticBytes = emit("emit_arithmetic_control_scb0.mjs");
const constructionBytes = emit("emit_construction_access_scb0.mjs");
const traversalBytes = emit("emit_traversal_scb0.mjs");
const kernelIfBytes = emit("emit_kernel_if_scb0.mjs");
const coverageGapBytes = emit("emit_coverage_gaps_scb0.mjs");
const payloadManifest = JSON.parse(fs.readFileSync(
  "spec/encoding/vectors/payload-records-v0.json", "utf8"));
if (payloadBytes.length !== payloadManifest.length) throw new Error("payload vector length mismatch");
const payloadDigest = createHash("sha256")
  .update(payloadManifest.digest_domain_ascii, "ascii")
  .update(Buffer.from(payloadManifest.digest_domain_terminator_hex, "hex"))
  .update(payloadBytes).digest("hex");
if (payloadDigest !== payloadManifest.module_sha256) throw new Error("payload vector digest mismatch");
const arithmeticManifest = JSON.parse(fs.readFileSync(
  "spec/encoding/vectors/arithmetic-control-v0.json", "utf8"));
if (arithmeticBytes.length !== arithmeticManifest.length) throw new Error("arithmetic vector length mismatch");
const arithmeticDigest = createHash("sha256")
  .update(arithmeticManifest.digest_domain_ascii, "ascii")
  .update(Buffer.from(arithmeticManifest.digest_domain_terminator_hex, "hex"))
  .update(arithmeticBytes).digest("hex");
if (arithmeticDigest !== arithmeticManifest.module_sha256) throw new Error("arithmetic vector digest mismatch");
const constructionManifest = JSON.parse(fs.readFileSync(
  "spec/encoding/vectors/construction-access-v0.json", "utf8"));
if (constructionBytes.length !== constructionManifest.length) throw new Error("construction vector length mismatch");
const constructionDigest = createHash("sha256")
  .update(constructionManifest.digest_domain_ascii, "ascii")
  .update(Buffer.from(constructionManifest.digest_domain_terminator_hex, "hex"))
  .update(constructionBytes).digest("hex");
if (constructionDigest !== constructionManifest.module_sha256) throw new Error("construction vector digest mismatch");
const traversalManifest = JSON.parse(fs.readFileSync(
  "spec/encoding/vectors/traversal-v0.json", "utf8"));
if (traversalBytes.length !== traversalManifest.length) throw new Error("traversal vector length mismatch");
const traversalDigest = createHash("sha256")
  .update(traversalManifest.digest_domain_ascii, "ascii")
  .update(Buffer.from(traversalManifest.digest_domain_terminator_hex, "hex"))
  .update(traversalBytes).digest("hex");
if (traversalDigest !== traversalManifest.module_sha256) throw new Error("traversal vector digest mismatch");
const kernelIfManifest = JSON.parse(fs.readFileSync(
  "spec/encoding/vectors/kernel-if-v0.json", "utf8"));
if (kernelIfBytes.length !== kernelIfManifest.length) throw new Error("kernel-if vector length mismatch");
const kernelIfDigest = createHash("sha256")
  .update(kernelIfManifest.digest_domain_ascii, "ascii")
  .update(Buffer.from(kernelIfManifest.digest_domain_terminator_hex, "hex"))
  .update(kernelIfBytes).digest("hex");
if (kernelIfDigest !== kernelIfManifest.module_sha256) throw new Error("kernel-if vector digest mismatch");
const coverageGapManifest = JSON.parse(fs.readFileSync(
  "spec/encoding/vectors/coverage-gaps-v0.json", "utf8"));
if (coverageGapBytes.length !== coverageGapManifest.length) throw new Error("coverage-gap vector length mismatch");
const coverageGapDigest = createHash("sha256")
  .update(coverageGapManifest.digest_domain_ascii, "ascii")
  .update(Buffer.from(coverageGapManifest.digest_domain_terminator_hex, "hex"))
  .update(coverageGapBytes).digest("hex");
if (coverageGapDigest !== coverageGapManifest.module_sha256) throw new Error("coverage-gap vector digest mismatch");

const freshCandidate = () => decodeModule(candidateBytes);
const freshBundle = () => decodeBundle(bundleBytes);
const expectAccepted = (name, decoded) => {
  checkTypedCore(decoded);
  console.log(`typed_core_positive=${name}`);
};
const expectRejected = (name, decoded, reason) => {
  try {
    checkTypedCore(decoded);
  } catch (error) {
    if (error instanceof AdmissionError && error.reason === reason) {
      console.log(`typed_core_hostile=${name} reason=${reason}`);
      return;
    }
    throw error;
  }
  throw new Error(`${name}: semantic check accepted; expected ${reason}`);
};

expectAccepted("minimal-module-v0", decodeModule(minimalBytes));
expectAccepted("candidate-selection-v0", freshCandidate());
expectAccepted("import-bundle-v0", freshBundle());
expectAccepted("payload-records-v0", decodeModule(payloadBytes));
expectAccepted("arithmetic-control-v0", decodeModule(arithmeticBytes));
expectAccepted("construction-access-v0", decodeModule(constructionBytes));
expectAccepted("traversal-v0", decodeModule(traversalBytes));
expectAccepted("kernel-if-v0", decodeModule(kernelIfBytes));
expectAccepted("coverage-gaps-v0", decodeModule(coverageGapBytes));

{
  const candidate = freshCandidate();
  candidate.kernels[0][1].body[1].claimedType = [1];
  expectRejected("false-claimed-type", candidate, "0800");
}
{
  const changed = Buffer.from(payloadBytes);
  const fieldName = changed.lastIndexOf(Buffer.from("right", "ascii"));
  if (fieldName < 0) throw new Error("payload field-name target absent");
  Buffer.from("sight", "ascii").copy(changed, fieldName);
  expectRejected("payload-field-name-mismatch-bytes", decodeModule(changed), "0806");
}
{
  const changed = Buffer.from(payloadBytes);
  const payloadType = Buffer.from("14000000000100000001", "hex");
  const typeAt = changed.lastIndexOf(payloadType);
  if (typeAt < 0) throw new Error("payload claimed-type target absent");
  changed[typeAt + payloadType.length - 1] = 0;
  expectRejected("payload-binder-type-mismatch-bytes", decodeModule(changed), "0604");
}
{
  const payload = decodeModule(payloadBytes);
  payload.functions[1][1].body.term[2].pop();
  expectRejected("record-field-missing", payload, "0805");
}
{
  const changed = Buffer.from(arithmeticBytes);
  const wrappingAdd = Buffer.from("04140100", "hex");
  const at = changed.indexOf(wrappingAdd);
  if (at < 0) throw new Error("wrapping-add policy target absent");
  changed[at + 2] = 0;
  expectRejected("arithmetic-policy-result-mismatch-bytes", decodeModule(changed), "0800");
}
{
  const arithmetic = decodeModule(arithmeticBytes);
  const choose = arithmetic.functions[3][1];
  choose.body.term[3] = { claimedType: [1], term: [4, 2] };
  expectRejected("if-branch-type-mismatch", arithmetic, "0807");
}
{
  const construction = decodeModule(constructionBytes);
  construction.functions[0][1].parameters[0] = [4];
  construction.functions[0][1].body.term[1].claimedType = [4];
  expectRejected("array-operation-collection-mismatch", construction, "080e");
}
{
  const changed = Buffer.from(constructionBytes);
  const none = Buffer.from("0f040a04", "hex");
  const at = changed.indexOf(none);
  if (at < 0) throw new Error("option-none target absent");
  changed[at + 3] = 1;
  expectRejected("option-item-claim-mismatch-bytes", decodeModule(changed), "0800");
}
{
  const construction = decodeModule(constructionBytes);
  construction.functions[6][1].body.term[2].term[1] = 2;
  expectRejected("let-local-out-of-scope", construction, "0702");
}
{
  const changed = Buffer.from(traversalBytes);
  const allTerm = Buffer.from("011e1201", "hex");
  const at = changed.indexOf(allTerm);
  if (at < 0) throw new Error("all traversal target absent");
  changed[at + 1] = 32;
  expectRejected("traversal-result-family-mismatch-bytes", decodeModule(changed), "0800");
}
{
  const traversal = decodeModule(traversalBytes);
  traversal.functions[2][1].body.term[3].parameters.pop();
  expectRejected("fold-block-parameter-mismatch", traversal, "080e");
}
{
  const kernelIf = decodeModule(kernelIfBytes);
  const body = kernelIf.kernels[0][1];
  body.parameters[0] = [4]; body.body[1].claimedType = [4];
  expectRejected("kernel-if-condition-not-bool", kernelIf, "0801");
}
{
  const kernelIf = decodeModule(kernelIfBytes);
  kernelIf.claims = kernelIf.claims.filter((claim) => claim !== 7);
  expectRejected("publication-eligible-without-publication-claim", kernelIf, "0a0a");
}
{
  const kernelIf = decodeModule(kernelIfBytes);
  kernelIf.theorems = kernelIf.theorems.filter((theorem) => theorem !== 6);
  expectRejected("publication-eligible-without-equivalence-requirement", kernelIf, "0a0a");
}
{
  const changed = Buffer.from(coverageGapBytes);
  const literal = Buffer.from("0b00000003030000000353454b", "hex");
  const at = changed.indexOf(literal);
  if (at < 0) throw new Error("bytes literal target absent");
  changed.writeUInt32BE(2, at + 1);
  expectRejected("bytes-literal-claim-length-mismatch-bytes", decodeModule(changed), "0800");
}
{
  const coverage = decodeModule(coverageGapBytes);
  const not = coverage.functions[4][1];
  not.parameters[0] = [3]; not.body.term[1].claimedType = [3];
  expectRejected("not-operand-not-bool", coverage, "0801");
}
{
  const candidate = freshCandidate();
  candidate.moduleBounds[6][0] = 1024;
  expectRejected("module-resource-ceiling-below-callable", candidate, "0b06");
}
{
  const candidate = freshCandidate();
  candidate.moduleBounds[1] = 33;
  expectRejected("module-import-ceiling-above-profile", candidate, "0b07");
}
{
  const candidate = freshCandidate();
  candidate.moduleBounds[2] = 4;
  expectRejected("module-declaration-count-exceeded", candidate, "0b06");
}
{
  const candidate = freshCandidate();
  candidate.moduleBounds[0] = 1020;
  expectRejected("module-byte-ceiling-exceeded", candidate, "0b06");
}
{
  const candidate = freshCandidate();
  candidate.moduleBounds[3] = 29;
  expectRejected("module-expression-count-exceeded", candidate, "0b06");
}
{
  const candidate = freshCandidate();
  candidate.moduleBounds[4] = 6;
  expectRejected("module-syntax-nesting-exceeded", candidate, "0b06");
}
{
  const bundle = freshBundle();
  bundle.rootModule.moduleBounds[5] = 2;
  expectRejected("module-call-depth-exceeded", bundle, "0b08");
}
{
  const construction = decodeModule(constructionBytes);
  construction.functions[0][1].parameters[0] = [18, [5], 0xffffffff];
  expectRejected("semantic-value-width-overflow", construction, "0b00");
}
{
  const traversal = decodeModule(traversalBytes);
  const all = traversal.functions[0][1];
  const hugeUnitArray = [18, [0], 0xffffffff];
  all.parameters[0] = hugeUnitArray;
  all.body.term[1].claimedType = hugeUnitArray;
  all.body.term[2].parameters[0] = [0];
  all.body.term[2].body = { claimedType: [1], term: [1, true] };
  expectRejected("traversal-step-multiplication-overflow", traversal, "0b00");
}
{
  const construction = decodeModule(constructionBytes);
  construction.functions[2][1].result = [14, 0];
  expectRejected("zero-index-bound", construction, "0600");
}
{
  const coverage = decodeModule(coverageGapBytes);
  coverage.functions[1][1].parameters[0] = [13, 0, 31];
  expectRejected("sha256-digest-wrong-length", coverage, "0601");
}
{
  const kernelIf = decodeModule(kernelIfBytes);
  kernelIf.types[0][1].body = [];
  expectRejected("empty-variant", kernelIf, "0603");
}
{
  const payload = decodeModule(payloadBytes);
  payload.functions[0][1].parameters[0] = [20, [[0, 1], 1]];
  expectRejected("variant-payload-in-public-signature", payload, "0604");
}
{
  const coverage = decodeModule(coverageGapBytes);
  coverage.functions[7][1].parameters[0] = [21, [0, 0]];
  expectRejected("declared-reference-to-alias", coverage, "0606");
}
{
  const payload = decodeModule(payloadBytes);
  payload.types[1][1].body[1][1].name = "Empty";
  expectRejected("duplicate-variant-case-name", payload, "0501");
}
{
  const payload = decodeModule(payloadBytes);
  const pair = payload.types[0][1];
  const recursive = [21, [0, 0]];
  pair.body[0][1] = recursive; pair.types[0] = recursive;
  expectRejected("recursive-type", payload, "0602");
}
for (const [name, mutate] of [
  ["empty-bytes-type", (module) => { module.functions[0][1].result = [11, 0]; }],
  ["empty-tuple-type", (module) => { module.functions[5][1].result = [17, []]; }],
  ["zero-length-array-type", (module) => { module.functions[0][1].parameters[0] = [18, [4], 0]; }]
]) {
  const module = name === "empty-bytes-type"
    ? decodeModule(coverageGapBytes) : decodeModule(constructionBytes);
  mutate(module);
  expectRejected(name, module, "0608");
}
{
  const construction = decodeModule(constructionBytes);
  construction.functions[0][1].parameters[0] = [18, [5], 131073];
  expectRejected("type-width-above-profile", construction, "0607");
}
{
  const traversal = decodeModule(traversalBytes);
  traversal.functions[0][1].exact[0] = 10;
  expectRejected("array-all-must-charge-static-length", traversal, "0b01");
}
{
  const traversal = decodeModule(traversalBytes);
  traversal.functions[3][1].exact[3] = 130;
  expectRejected("map-workspace-omits-output", traversal, "0b04");
}
{
  const construction = decodeModule(constructionBytes);
  const pair = construction.functions[5][1].body;
  pair.term[1].pop();
  expectRejected("tuple-claim-mismatch", construction, "0800");
}
{
  const arithmetic = decodeModule(arithmeticBytes);
  const negate = arithmetic.functions[7][1];
  negate.parameters[0] = [4]; negate.result = [16, [4], [10]];
  negate.body.claimedType = [16, [4], [10]]; negate.body.term[3].claimedType = [4];
  expectRejected("unsigned-negation", arithmetic, "080d");
}
{
  const arithmetic = decodeModule(arithmeticBytes);
  const shift = arithmetic.functions[8][1];
  shift.parameters[1] = [1]; shift.body.term[4].claimedType = [1];
  expectRejected("shift-count-not-u32", arithmetic, "080c");
}
{
  const candidate = freshCandidate();
  const predicate = candidate.kernels[0][1].body[1].term[2].body;
  predicate.term[1].term[2][0][1][1] = 3;
  expectRejected("projection-owner-mismatch", candidate, "0704");
}
{
  const bundle = freshBundle();
  const base = bundle.modules.find((module) => module.functions.length === 1);
  const keep = base.functions[0][1];
  keep.parameters[0] = [4];
  keep.result = [4];
  keep.body.claimedType = [4];
  expectRejected("reopened-import-signature-mismatch", bundle, "0803");
}
for (const [name, component, reason] of [
  ["false-exact-steps", 0, "0b01"],
  ["false-exact-live-bits", 1, "0b02"],
  ["false-exact-control-depth", 2, "0b03"],
  ["false-exact-workspace", 3, "0b04"]
]) {
  const candidate = freshCandidate();
  candidate.kernels[0][1].exact[component] += 1;
  expectRejected(name, candidate, reason);
}
{
  const candidate = freshCandidate();
  candidate.kernels[0][1].declared[0] = 211;
  expectRejected("callable-ceiling-below-exact", candidate, "0b05");
}

console.log("typed_core_semantics=verified positive=9 hostile=48 byte_hostile=6");
