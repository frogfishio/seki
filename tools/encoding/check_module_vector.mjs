import { createHash } from "node:crypto";
import fs from "node:fs";

const [cPath, jsPath, vectorPath] = process.argv.slice(2);
if (!cPath || !jsPath || !vectorPath) {
  throw new Error("usage: check_module_vector.mjs C_BYTES JS_BYTES VECTOR_JSON");
}

const cBytes = fs.readFileSync(cPath);
const jsBytes = fs.readFileSync(jsPath);
const vector = JSON.parse(fs.readFileSync(vectorPath, "utf8"));

if (!cBytes.equals(jsBytes)) {
  throw new Error("independent C and JavaScript fixture emitters disagree");
}
if (cBytes.length !== vector.module_length) {
  throw new Error("emitted module length differs from recorded vector");
}
if (cBytes.toString("hex") !== vector.module_hex) {
  throw new Error("emitted module differs from recorded vector");
}

const hash = createHash("sha256");
hash.update(vector.digest_domain_ascii, "ascii");
hash.update(Buffer.from(vector.digest_domain_terminator_hex, "hex"));
hash.update(cBytes);
const digest = hash.digest("hex");
if (digest !== vector.module_sha256) {
  throw new Error("module digest differs from recorded vector");
}

console.log(
  `scb0_vector=verified fixture=${vector.fixture} ` +
  `bytes=${cBytes.length} sha256=${digest}`
);

