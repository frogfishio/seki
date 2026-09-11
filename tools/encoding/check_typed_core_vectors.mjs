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
  const payloadType = Buffer.from("15000000000100000001", "hex");
  const typeAt = changed.lastIndexOf(payloadType);
  if (typeAt < 0) throw new Error("payload claimed-type target absent");
  changed[typeAt + payloadType.length - 1] = 0;
  expectRejected("payload-binder-type-mismatch-bytes", decodeModule(changed), "0800");
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

console.log("typed_core_semantics=verified positive=5 hostile=15 byte_hostile=3");
