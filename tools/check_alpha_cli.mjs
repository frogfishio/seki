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
  "src/alpha/seki_c_backend.c",
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
    "sekic 0.0.0-alpha.5 (provisional, authority=none)\n");

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

  const renamedSource = path.join(temporary, "gate_policy.seki");
  const renamedCore = path.join(temporary, "gate_policy.scb0");
  const renamedC = path.join(temporary, "gate_policy.c");
  const renamedText = fs.readFileSync(canonicalSource, "utf8")
    .replace("minimum_age", "gate_policy")
    .replaceAll("Applicant", "Signal")
    .replaceAll("Rejection", "Denial")
    .replaceAll("Underage", "Below")
    .replaceAll("decide", "screen")
    .replaceAll("applicant", "signal")
    .replaceAll("age", "level")
    .replace("Below @ 1.", "Below @ 7.")
    .replace("< 18", "< 42");
  fs.writeFileSync(renamedSource, renamedText);

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

  const renamed = run([
    "build", "--core", renamedCore, "--c", renamedC, renamedSource,
  ]);
  assert.equal(renamed.status, 0, renamed.stderr);
  const renamedCText = fs.readFileSync(renamedC, "utf8");
  assert.match(renamedCText, /seki_a0_gate_policy_signal/u);
  assert.match(renamedCText, /seki_a0_gate_policy_screen/u);
  assert.match(renamedCText,
    /seki_p_signal\.seki_f_level < UINT8_C\(42\)/u);
  assert.match(renamedCText, /result\.reason = UINT8_C\(7\)/u);
  execFileSync("cc", [...strictFlags, "-c", renamedC, "-o",
    path.join(temporary, "gate_policy.o")], { stdio: "inherit" });

  const outsideSliceSource = path.join(temporary, "outside-slice.seki");
  fs.writeFileSync(outsideSliceSource,
    fs.readFileSync(canonicalSource, "utf8").replace("< 18", "> 18"));
  const outsideSlice = run(["check", outsideSliceSource]);
  assert.equal(outsideSlice.status, 65);
  assert.match(outsideSlice.stderr,
    /^A0-CORE-0001:.*: module is outside the U8-decision core slice\n$/u);

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
    "frontend=alpha-u8-decision\n" +
    "backend=alpha-u8-decision\n" +
    "profile=c11_bounded@1\n" +
    "threshold_u8=18\n" +
    "authority=none\n");

  const badMagicPath = path.join(temporary, "bad-magic.scb0");
  const badMagicCore = fs.readFileSync(corePath);
  badMagicCore[0] ^= 0xff;
  fs.writeFileSync(badMagicPath, badMagicCore);
  const badMagic = run(["inspect", badMagicPath]);
  assert.equal(badMagic.status, 65);
  assert.match(badMagic.stderr,
    /^A0-BACKEND-0001:.*:\d+: bad SCB-0 magic\n$/u);

  const trailingPath = path.join(temporary, "trailing.scb0");
  fs.writeFileSync(trailingPath,
    Buffer.concat([fs.readFileSync(corePath), Buffer.from([0])]));
  const trailing = run(["inspect", trailingPath]);
  assert.equal(trailing.status, 65);
  assert.match(trailing.stderr,
    /^A0-BACKEND-0001:.*:\d+: SCB-0 payload length mismatch\n$/u);

  const overwrite = run([
    "build", "--core", corePath, "--c", cPath, canonicalSource,
  ]);
  assert.equal(overwrite.status, 74);
  assert.match(overwrite.stderr, /^A0-IO-0002:/u);

  const bad = run(["build", canonicalSource]);
  assert.equal(bad.status, 64);
  assert.match(bad.stderr, /^usage:\n/u);

  console.log(
    "seki_alpha_cli=verified version=0.0.0-alpha.5 commands=4 connected=3 " +
    "slice=u8-decision renamed=yes overwrite=reject",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
