import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-a0-cli-"));
const compiler = path.join(temporary, "sekic");
const canonicalSource = "experiments/e0-vs1/minimum_age.seki";
const recordedCore = "experiments/e0-vs1/minimum_age.scb0.hex";
const recordedC = "experiments/e0-vs1/minimum_age.generated.c";
const sources = [
  "src/alpha/sekic.c",
  "src/alpha/seki_lexer.c",
  "src/alpha/seki_parser.c",
  "src/alpha/seki_checker.c",
  "src/alpha/seki_core.c",
  "src/alpha/e0_backend_adapter.c",
];
const strictFlags = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wstrict-prototypes",
  "-Wmissing-prototypes", "-Wundef", "-Wformat=2",
];

function run(args) {
  return spawnSync(compiler, args, { encoding: "utf8" });
}

try {
  execFileSync("cc", [
    ...strictFlags,
    "-Isrc/alpha",
    ...sources,
    "-o", compiler,
  ], { stdio: "inherit" });

  const version = run(["--version"]);
  assert.equal(version.status, 0);
  assert.equal(version.stderr, "");
  assert.equal(version.stdout,
    "sekic 0.0.0-alpha.3 (provisional, authority=none)\n");

  const help = run(["--help"]);
  assert.equal(help.status, 0);
  assert.match(help.stdout, /^usage:\n/u);
  assert.equal(help.stderr, "");

  const checked = run(["check", canonicalSource]);
  assert.equal(checked.status, 0, checked.stderr);
  assert.equal(checked.stdout, "");
  assert.equal(checked.stderr, "");

  const hostileSource = path.join(temporary, "hostile.seki");
  fs.writeFileSync(hostileSource,
    fs.readFileSync(canonicalSource, "utf8").replace("< 18", "< 256"));
  const hostile = run(["check", hostileSource]);
  assert.equal(hostile.status, 65);
  assert.match(hostile.stderr,
    /^A0-CHECK-0004:.*: comparison operands are incompatible\n$/u);

  const duplicateHeader = path.join(temporary, "duplicate-header.seki");
  fs.writeFileSync(duplicateHeader,
    fs.readFileSync(canonicalSource, "utf8").replace(
      "semantic_evaluation, lean_projection, restricted_c_source",
      "semantic_evaluation, semantic_evaluation, restricted_c_source"));
  const duplicate = run(["check", duplicateHeader]);
  assert.equal(duplicate.status, 65);
  assert.match(duplicate.stderr,
    /^A0-PARSE-0007:.*:\d+:\d+: duplicate header name\n$/u);

  const unsupportedSource = path.join(temporary, "unsupported-shape.seki");
  fs.writeFileSync(unsupportedSource,
    fs.readFileSync(canonicalSource, "utf8").replace(
      "minimum_age", "different_policy"));
  const unsupported = run(["check", unsupportedSource]);
  assert.equal(unsupported.status, 65);
  assert.match(unsupported.stderr,
    /^A0-CORE-0001:.*: module is outside the current core-emission slice\n$/u);

  const corePath = path.join(temporary, "minimum_age.scb0");
  const cPath = path.join(temporary, "minimum_age.c");
  const built = run([
    "build", "--core", corePath, "--c", cPath, canonicalSource,
  ]);
  assert.equal(built.status, 0, built.stderr);
  assert.equal(built.stdout, "");
  assert.equal(built.stderr, "");
  assert.deepEqual(fs.readFileSync(corePath),
    Buffer.from(fs.readFileSync(recordedCore, "ascii").trim(), "hex"));
  assert.deepEqual(fs.readFileSync(cPath), fs.readFileSync(recordedC));

  const variantSource = path.join(temporary, "minimum_age_19.seki");
  const variantCore = path.join(temporary, "minimum_age_19.scb0");
  const variantC = path.join(temporary, "minimum_age_19.c");
  fs.writeFileSync(variantSource,
    fs.readFileSync(canonicalSource, "utf8").replace("< 18", "< 19"));
  const variant = run([
    "build", "--core", variantCore, "--c", variantC, variantSource,
  ]);
  assert.equal(variant.status, 0, variant.stderr);
  assert.notDeepEqual(fs.readFileSync(variantCore), fs.readFileSync(corePath));
  assert.match(fs.readFileSync(variantC, "utf8"),
    /applicant\.age < UINT8_C\(19\)/u);

  const inspected = run(["inspect", corePath]);
  assert.equal(inspected.status, 0, inspected.stderr);
  assert.equal(inspected.stderr, "");
  assert.equal(inspected.stdout,
    "frontend=alpha-minimum-age\n" +
    "backend=e0-vs1\n" +
    "profile=c11_bounded@1\n" +
    "threshold_u8=18\n" +
    "authority=none\n");

  const overwrite = run([
    "build", "--core", corePath, "--c", cPath, canonicalSource,
  ]);
  assert.equal(overwrite.status, 74);
  assert.match(overwrite.stderr, /^A0-IO-0002:/u);

  const bad = run(["build", canonicalSource]);
  assert.equal(bad.status, 64);
  assert.match(bad.stderr, /^usage:\n/u);

  console.log(
    "seki_alpha_cli=verified version=0.0.0-alpha.3 commands=4 connected=3 " +
    "frontend=alpha-minimum-age backend=e0-vs1 overwrite=reject",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
