import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { decodeModule } from "./encoding/decode_scb0.mjs";
import { checkTypedCore } from "./encoding/check_typed_core.mjs";

const root = process.cwd();
const sourcePath = path.join(root, "experiments/e0-vs1/minimum_age.seki");
const recordedPath = path.join(root, "experiments/e0-vs1/minimum_age.scb0.hex");
const emitterPath = path.join(root, "tools/encoding/emit_e0_minimum_age_scb0.mjs");
const compilerSource = path.join(root, "src/e0/sekic_e0.c");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-e0-frontend-"));
const compiler = path.join(temporary, "sekic-e0");

const strictFlags = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wstrict-prototypes",
  "-Wmissing-prototypes", "-Wundef", "-Wformat=2",
];

function compile(source, outputName) {
  const input = path.join(temporary, `${outputName}.seki`);
  const output = path.join(temporary, `${outputName}.scb0`);
  fs.writeFileSync(input, source);
  const result = spawnSync(compiler, [input, output], { encoding: "utf8" });
  assert.equal(result.status, 0, `frontend rejected ${outputName}: ${result.stderr}`);
  assert.equal(result.stderr, "", `frontend diagnosed successful ${outputName}`);
  return fs.readFileSync(output);
}

function reject(source, outputName, diagnostic) {
  const input = path.join(temporary, `${outputName}.seki`);
  const output = path.join(temporary, `${outputName}.scb0`);
  fs.writeFileSync(input, source);
  const result = spawnSync(compiler, [input, output], { encoding: "utf8" });
  assert.equal(result.status, 65, `${outputName} returned ${result.status}: ${result.stderr}`);
  assert.match(result.stderr, /^E0-SOURCE:\d+:\d+: /u);
  assert.match(result.stderr, diagnostic);
  assert.equal(fs.existsSync(output), false, `${outputName} created an artifact`);
}

function replaceOnce(source, before, after) {
  assert.equal(source.split(before).length, 2, `mutation anchor is not unique: ${before}`);
  return source.replace(before, after);
}

try {
  execFileSync("cc", [...strictFlags, compilerSource, "-o", compiler], {
    stdio: "inherit",
  });

  const source = fs.readFileSync(sourcePath, "utf8");
  const recorded = Buffer.from(fs.readFileSync(recordedPath, "ascii").trim(), "hex");
  const independent = execFileSync(process.execPath, [emitterPath]);
  const first = compile(source, "canonical-first");
  const second = compile(source, "canonical-second");

  assert.deepEqual(first, recorded, "C frontend differs from recorded SCB-0");
  assert.deepEqual(first, independent, "C and JavaScript emitters differ");
  assert.deepEqual(first, second, "C frontend output is nondeterministic");
  checkTypedCore(decodeModule(first));

  const threshold19 = compile(replaceOnce(source, "< 18", "< 19"), "threshold-19");
  checkTypedCore(decodeModule(threshold19));
  const changed = [];
  for (let index = 0; index < first.length; index += 1) {
    if (first[index] !== threshold19[index]) changed.push(index);
  }
  assert.equal(changed.length, 1, "threshold mutation did not change exactly one SCB byte");
  assert.equal(first[changed[0]], 18);
  assert.equal(threshold19[changed[0]], 19);

  reject(replaceOnce(source, "< 18", "< 256"), "threshold-overflow", /does not fit U8/u);
  reject(replaceOnce(source, "age: U8", "age: U16"), "wrong-field-type", /unexpected identifier/u);
  reject(replaceOnce(source, "steps: 32", "steps: 7"), "insufficient-steps", /below the derived/u);
  reject(replaceOnce(source,
    "ifTrue: [ reject Rejection::Underage ]",
    "ifTrue: [ accept unit ]"), "wrong-true-branch", /unexpected identifier/u);
  reject(`${source}\nexport record Extra { value: U8 }.\n`, "trailing-declaration", /unexpected declaration/u);
  reject(replaceOnce(source, "publication: none", "publication: #none"),
    "unsupported-character", /unsupported character/u);

  const digest = createHash("sha256")
    .update("io.frogfish.seki/module/scb0/sha256", "ascii")
    .update(Buffer.from([0]))
    .update(first).digest("hex");
  console.log(
    `e0_frontend=verified bytes=${first.length} sha256=${digest} ` +
    "positive=3 hostile=6 strict_c11=yes",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
