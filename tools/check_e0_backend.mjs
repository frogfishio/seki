import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const root = process.cwd();
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-e0-backend-"));
const frontend = path.join(temporary, "sekic-e0");
const backend = path.join(temporary, "seki-e0-c-backend");
const sourcePath = path.join(root, "experiments/e0-vs1/minimum_age.seki");
const recordedCPath = path.join(root, "experiments/e0-vs1/minimum_age.generated.c");
const frontendSource = path.join(root, "src/e0/sekic_e0.c");
const backendSource = path.join(root, "src/e0/seki_e0_c_backend.c");

const strictFlags = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wstrict-prototypes",
  "-Wmissing-prototypes", "-Wundef", "-Wformat=2",
];

function run(command, args, options = {}) {
  return execFileSync(command, args, { stdio: "inherit", ...options });
}

function compileTool(source, output) {
  run("cc", [...strictFlags, source, "-o", output]);
}

function buildFromSource(source, stem) {
  const sourceFile = path.join(temporary, `${stem}.seki`);
  const scbFile = path.join(temporary, `${stem}.scb0`);
  const cFile = path.join(temporary, `${stem}.c`);
  fs.writeFileSync(sourceFile, source);
  run(frontend, [sourceFile, scbFile]);
  run(backend, [scbFile, cFile]);
  return { scbFile, cFile, cBytes: fs.readFileSync(cFile) };
}

function writeRunner(generatedName, threshold, stem) {
  const runner = path.join(temporary, `${stem}-runner.c`);
  fs.writeFileSync(runner,
`#include <stdint.h>
#include "${generatedName}"

int
main(void)
{
    uint16_t age;
    for (age = UINT16_C(0); age <= UINT16_C(255); age += UINT16_C(1)) {
        seki_e0_applicant applicant;
        seki_e0_decision decision;
        const uint8_t expected_tag = age < UINT16_C(${threshold}) ? UINT8_C(1) : UINT8_C(0);
        const uint8_t expected_reason = expected_tag;
        applicant.age = (uint8_t)age;
        decision = seki_e0_decide(applicant);
        if (decision.tag != expected_tag || decision.reason != expected_reason) {
            return 1;
        }
    }
    return 0;
}
`);
  return runner;
}

function compileAndRun(generated, threshold, stem, sanitizer) {
  const runner = writeRunner(path.basename(generated), threshold, stem);
  const executable = path.join(temporary, `${stem}-runner`);
  const sanitizerFlags = sanitizer
    ? ["-O1", "-g", "-fsanitize=address,undefined", "-fno-omit-frame-pointer"]
    : [];
  run("cc", [...strictFlags, ...sanitizerFlags, runner, "-o", executable]);
  run(executable, [], sanitizer
    ? { env: { ...process.env, ASAN_OPTIONS: "detect_leaks=0" } }
    : {});
}

function rejectScb(bytes, stem, diagnostic) {
  const input = path.join(temporary, `${stem}.scb0`);
  const output = path.join(temporary, `${stem}.c`);
  fs.writeFileSync(input, bytes);
  const result = spawnSync(backend, [input, output], { encoding: "utf8" });
  assert.equal(result.status, 65, `${stem} returned ${result.status}: ${result.stderr}`);
  assert.match(result.stderr, /^E0-SCB:\d+: /u);
  assert.match(result.stderr, diagnostic);
  assert.equal(fs.existsSync(output), false, `${stem} created C output`);
}

try {
  compileTool(frontendSource, frontend);
  compileTool(backendSource, backend);

  const source = fs.readFileSync(sourcePath, "utf8");
  const recordedC = fs.readFileSync(recordedCPath);
  const canonical = buildFromSource(source, "canonical");
  const repeated = buildFromSource(source, "repeated");
  assert.deepEqual(canonical.cBytes, recordedC, "backend differs from recorded C");
  assert.deepEqual(canonical.cBytes, repeated.cBytes, "backend output is nondeterministic");

  compileAndRun(canonical.cFile, 18, "canonical", false);
  compileAndRun(canonical.cFile, 18, "canonical-sanitized", true);

  const threshold19Source = source.replace("< 18", "< 19");
  assert.notEqual(threshold19Source, source);
  const threshold19 = buildFromSource(threshold19Source, "threshold-19");
  assert.notDeepEqual(threshold19.cBytes, canonical.cBytes);
  assert.match(threshold19.cBytes.toString("ascii"), /UINT8_C\(19\)/u);
  compileAndRun(threshold19.cFile, 19, "threshold-19", false);

  const validScb = fs.readFileSync(canonical.scbFile);
  rejectScb(validScb.subarray(0, validScb.length - 1), "truncated", /payload length mismatch|truncated/u);
  rejectScb(Buffer.concat([validScb, Buffer.from([0])]), "trailing", /payload length mismatch|trailing/u);
  const changedBody = Buffer.from(validScb);
  changedBody[208] ^= 1;
  rejectScb(changedBody, "changed-kernel-shape", /must|requires|unexpected|expected/u);

  const digest = createHash("sha256").update(canonical.cBytes).digest("hex");
  console.log(
    `e0_backend=verified c_bytes=${canonical.cBytes.length} c_sha256=${digest} ` +
    "ages=256 threshold_variant=yes hostile=3 asan_ubsan=yes",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
