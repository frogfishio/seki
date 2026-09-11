// Experimental semantic hostile checks over independently decoded SCB-0 objects.
import { execFileSync } from "node:child_process";
import { AdmissionError, decodeBundle, decodeModule } from "./decode_scb0.mjs";
import { checkTypedCore } from "./check_typed_core.mjs";

const emit = (name, mode) => execFileSync(process.execPath,
  [`tools/encoding/${name}`, ...(mode ? [mode] : [])]);
const minimalBytes = emit("emit_minimal_scb0.mjs");
const candidateBytes = emit("emit_candidate_selection_scb0.mjs");
const bundleBytes = emit("emit_import_bundle_scb0.mjs", "--bundle");

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

{
  const candidate = freshCandidate();
  candidate.kernels[0][1].body[1].claimedType = [1];
  expectRejected("false-claimed-type", candidate, "0800");
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

console.log("typed_core_semantics=verified positive=3 hostile=8");
