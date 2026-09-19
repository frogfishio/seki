import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import { decodeModule } from "./decode_scb0.mjs";
import { checkTypedCore } from "./check_typed_core.mjs";

const emitter = "tools/encoding/emit_e0_minimum_age_scb0.mjs";
const hexPath = "experiments/e0-vs1/minimum_age.scb0.hex";
const vectorPath = "spec/encoding/vectors/e0-minimum-age-v0.json";

const emitted = execFileSync(process.execPath, [emitter]);
const recorded = Buffer.from(fs.readFileSync(hexPath, "ascii").trim(), "hex");
const vector = JSON.parse(fs.readFileSync(vectorPath, "utf8"));

if (!emitted.equals(recorded)) {
  throw new Error("E0 emitter output differs from the exact recorded SCB-0 bytes");
}
if (recorded.length !== vector.length) {
  throw new Error("E0 SCB-0 length differs from the vector manifest");
}

const digest = createHash("sha256")
  .update(vector.digest_domain_ascii, "ascii")
  .update(Buffer.from(vector.digest_domain_terminator_hex, "hex"))
  .update(recorded).digest("hex");
if (digest !== vector.module_sha256) {
  throw new Error("E0 SCB-0 module digest differs from the vector manifest");
}

const module = decodeModule(recorded);
checkTypedCore(module);
const kernel = module.kernels[0][1];
const expectedBounds = Object.values(vector.exact_resource_bounds);
if (JSON.stringify(kernel.exact) !== JSON.stringify(expectedBounds)) {
  throw new Error("E0 exact resource bounds differ from the vector manifest");
}

console.log(
  `e0_vs1_scb0=verified bytes=${recorded.length} sha256=${digest} ` +
  `bounds=${kernel.exact.join(",")}`
);
