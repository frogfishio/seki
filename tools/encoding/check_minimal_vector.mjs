import { createHash } from "node:crypto";
import fs from "node:fs";

const [cPath, jsPath, vectorPath] = process.argv.slice(2);
if (!cPath || !jsPath || !vectorPath) {
  throw new Error("usage: check_minimal_vector.mjs C_BYTES JS_BYTES VECTOR_JSON");
}

const cBytes = fs.readFileSync(cPath);
const jsBytes = fs.readFileSync(jsPath);
const vector = JSON.parse(fs.readFileSync(vectorPath, "utf8"));

if (!cBytes.equals(jsBytes)) {
  throw new Error("independent C and JavaScript fixture emitters disagree");
}
if (cBytes.toString("hex") !== vector.module_hex) {
  throw new Error("emitted minimal module differs from recorded vector");
}

const hash = createHash("sha256");
hash.update("io.frogfish.seki/module/scb0/sha256", "ascii");
hash.update(Buffer.from([0]));
hash.update(cBytes);
const digest = hash.digest("hex");
if (digest !== vector.module_sha256) {
  throw new Error("minimal module digest differs from recorded vector");
}

console.log(
  `scb0_minimal_vector=verified bytes=${cBytes.length} sha256=${digest}`
);

