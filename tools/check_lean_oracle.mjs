import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/*
 * Differential execution of sekic's generated C against Seki.eval, the Lean
 * evaluator of the typed core (formal/seki, VISION.md §17 step 4).
 *
 * For every kernel in the corpus: sekic builds the typed core and the C; the
 * Lean oracle decodes the exact typed-core bytes, generates inputs from the
 * kernel's parameter type, evaluates each with Seki.eval, and emits a C program
 * that runs the same inputs through the generated kernel and compares every
 * defined decision field. The expected decisions come from the typed core, not
 * from a reference policy written by the compiler's authors.
 *
 * A negative control changes one literal in one generated kernel and requires
 * the oracle to disagree, so a harness that could never fail cannot pass.
 *
 * Without Lean the check reports that it was skipped and succeeds; a skipped
 * check is not a passed one, and the printed line says so.
 */

const lake = spawnSync("lake", ["--version"], { encoding: "utf8" });
if (lake.error !== undefined || lake.status !== 0) {
  console.log("lean_oracle=skipped reason=lake-not-available");
  process.exit(0);
}

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-oracle-"));
const compiler = path.join(temporary, "sekic");
const strictFlags = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wundef",
];
const vectors = 2000;

// The quickstart kernel, exactly as the document prints it.
const quickstart = fs.readFileSync("docs/alpha/QUICKSTART.md", "utf8");
const quickstartKernel = /```seki\n([\s\S]*?)```/u.exec(quickstart)[1];
fs.writeFileSync(path.join(temporary, "quickstart.seki"), quickstartKernel);

const corpus = [
  "experiments/e0-vs1/minimum_age.seki",
  "spec/language/examples/access_permit.seki",
  path.join(temporary, "quickstart.seki"),
  ...fs.readdirSync("tests/oracle").filter((f) => f.endsWith(".seki"))
    .sort().map((f) => path.join("tests/oracle", f)),
];

try {
  execFileSync("cc", [...strictFlags, "-Isrc/alpha",
    "src/alpha/sekic.c", "src/alpha/seki_lexer.c", "src/alpha/seki_parser.c",
    "src/alpha/seki_types.c", "src/alpha/seki_checker.c",
    "src/alpha/seki_core.c", "src/alpha/seki_c_backend.c",
    "-o", compiler], { stdio: "inherit" });
  execFileSync("lake", ["build"], { cwd: "formal/seki", stdio: "pipe" });

  const oracle = (core, out) => execFileSync("lake",
    ["exe", "oracle", "harness", core, String(vectors), out],
    { cwd: "formal/seki", stdio: "pipe" });

  let total = 0;
  const built = new Map();
  for (const source of corpus) {
    const name = path.basename(source, ".seki");
    const dir = path.join(temporary, name);
    fs.mkdirSync(dir);
    const core = path.join(dir, "kernel.scb0");
    const kernelC = path.join(dir, "kernel.c");
    // The generated C includes `seki_a0_<last module path component>.h`.
    const module = /^module\s+([\w:]+)\s*@/mu.exec(fs.readFileSync(source, "utf8"));
    assert.ok(module !== null, `${source}: no module line`);
    const headerName = `seki_a0_${module[1].split("::").at(-1).toLowerCase()}.h`;
    const build = spawnSync(compiler, ["build", "--core", core, "--c", kernelC,
      "--header", path.join(dir, headerName), source], { encoding: "utf8" });
    assert.equal(build.status, 0, `${source}: ${build.stderr}`);

    const harness = path.join(dir, "oracle.c");
    oracle(core, harness);
    const binary = path.join(dir, "oracle");
    execFileSync("cc", [...strictFlags, `-I${dir}`, kernelC, harness, "-o", binary],
      { stdio: "inherit" });
    const result = spawnSync(binary, [], { encoding: "utf8" });
    assert.equal(result.status, 0,
      `${source}: sekic's C disagrees with Seki.eval\n${result.stdout}${result.stderr}`);
    assert.match(result.stdout, /^lean_oracle=agrees /u);
    console.log(`  ${name}: ${result.stdout.trim()}`);
    total += vectors;
    built.set(name, { dir, kernelC, harness });
  }

  // Negative control: one changed literal in the quickstart kernel's C.
  const control = built.get("quickstart");
  const mutated = path.join(control.dir, "mutated.c");
  const original = fs.readFileSync(control.kernelC, "utf8");
  assert.ok(original.includes("UINT8_C(18)"), "the control literal is missing");
  fs.writeFileSync(mutated, original.replace("UINT8_C(18)", "UINT8_C(17)"));
  const mutatedBinary = path.join(control.dir, "mutated");
  execFileSync("cc", [...strictFlags, `-I${control.dir}`, mutated, control.harness,
    "-o", mutatedBinary], { stdio: "inherit" });
  const caught = spawnSync(mutatedBinary, [], { encoding: "utf8" });
  assert.equal(caught.status, 1, "the oracle did not notice a changed kernel");
  assert.match(caught.stdout, /^lean_oracle=DISAGREES /u);

  console.log(`lean_oracle=verified kernels=${corpus.length} vectors=${total} ` +
    "negative_control=caught");
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
