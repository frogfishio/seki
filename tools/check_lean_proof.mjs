import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/*
 * Checks the E0 Lean proof against the exact toolchain the foundation lock
 * names.
 *
 * `lean-toolchain` pins the toolchain, so elan resolves a bare `lean` to that
 * version. The binary reports the upstream commit it was built from, which
 * must equal the commit recorded in the lock: that turns "we bound Lean
 * 4.30.0" from a claim in a JSON file into something this check verifies.
 *
 * When Lean is absent the check reports that it was skipped and succeeds, so
 * the portfolio still runs in the pinned Node container. A skipped check is
 * not a passed one, and the printed line says so.
 */

const lock = JSON.parse(
  fs.readFileSync("foundations/FOUNDATION_LOCK.json", "utf8"));
const { lean } = lock.foundations;
const proof = "formal/lean/E0/MinimumAge.lean";
const toolchain = fs.readFileSync("lean-toolchain", "utf8").trim();

assert.equal(toolchain, `leanprover/lean4:v${lean.version}`,
  "lean-toolchain and the foundation lock name different Lean versions");

const version = spawnSync("lean", ["--version"], { encoding: "utf8" });
if (version.error !== undefined || version.status !== 0) {
  console.log(
    `lean_proof=skipped reason=lean-not-available expected=${toolchain}`);
  process.exit(0);
}

const reported = /commit ([0-9a-f]{40})/u.exec(version.stdout);
assert.ok(reported !== null,
  `cannot read a commit identity from: ${version.stdout.trim()}`);
assert.equal(reported[1], lean.commit,
  "the installed Lean was not built from the locked commit");
assert.ok(version.stdout.includes(`version ${lean.version},`),
  `installed Lean is not ${lean.version}: ${version.stdout.trim()}`);

execFileSync("lean", [proof], { stdio: "inherit" });

/*
 * E0 is a completed experiment, frozen and bound by digest in its manifest.
 * Its `decodeExactProgram_eq` is discharged by `native_decide`, which trusts
 * Lean's compiler and runtime. It is kept as the record of what E0 did, not as
 * the project's proof: that is formal/seki, below, which uses none. The count
 * is asserted so that the record cannot change quietly.
 */
const source = fs.readFileSync(proof, "utf8");
const nativeDecides = (source.match(/\bnative_decide\b/gu) ?? []).length;
assert.equal(nativeDecides, 1,
  `expected exactly one native_decide in the E0 record, found ${nativeDecides}`);
const theorems = (source.match(/^theorem /gmu) ?? []).length;
assert.ok(!/\bsorry\b/u.test(source), "the proof contains sorry");
assert.ok(!/^axiom /mu.test(source), "the proof declares an axiom");

/*
 * formal/seki: the minimum-age requirement proved of the kernel's exact
 * typed-core bytes, decoded and evaluated by the Lean kernel alone.
 */
const seki = "formal/seki";
assert.equal(fs.readFileSync(path.join(seki, "lean-toolchain"), "utf8").trim(),
  toolchain, "formal/seki names a different Lean toolchain");

// The byte literal the proof reads is exactly the recorded typed core.
const bytesModule = path.join(seki, "Seki/Proofs/MinimumAgeBytes.lean");
const regenerated = path.join(os.tmpdir(), `seki-bytes-${process.pid}.lean`);
execFileSync("node", ["tools/lean_bytes.mjs",
  "experiments/e0-vs1/minimum_age.scb0.hex", "Seki.Proofs.MinimumAge", regenerated]);
assert.ok(fs.readFileSync(regenerated).equals(fs.readFileSync(bytesModule)),
  "MinimumAgeBytes.lean does not match experiments/e0-vs1/minimum_age.scb0.hex");
fs.rmSync(regenerated);

// Source policy: nothing that widens trust past the Lean kernel.
const sekiSources = [];
const walk = (dir) => {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== ".lake") walk(full);
    } else if (entry.name.endsWith(".lean")) {
      sekiSources.push(full);
    }
  }
};
walk(seki);
for (const file of sekiSources) {
  const text = fs.readFileSync(file, "utf8");
  for (const [pattern, description] of [
    [/\bsorry\b|\badmit\b/u, "sorry/admit"],
    [/^[ \t]*(private |protected )?axiom\b/mu, "user axiom"],
    [/\b(partial|unsafe)[ \t]+(def|abbrev|instance|opaque)\b/u,
      "partial/unsafe definition"],
    [/\bnative_decide\b|Lean\.ofReduceBool/u, "native decision"],
    [/@\[(extern|export)|implemented_by/u, "FFI attribute"],
  ]) {
    assert.ok(!pattern.test(text), `${file}: policy violation: ${description}`);
  }
}

execFileSync("lake", ["build"], { cwd: seki, stdio: "pipe" });
const audit = execFileSync("lake", ["env", "lean", "Audit/Axioms.lean"],
  { cwd: seki, encoding: "utf8" });
const audited = /seki_axiom_audit=verified constants=(\d+)/u.exec(audit);
assert.ok(audited !== null, `axiom audit did not verify: ${audit}`);
// The theorems prove exactly the statements written out in Audit/Statements.
const statements = execFileSync("lake", ["env", "lean", "Audit/Statements.lean"],
  { cwd: seki, encoding: "utf8" });
assert.match(statements, /seki_statements=verified totality=pinned minimum_age=pinned/u);

// Negative control: the same proof over bytes whose threshold is 19 must fail.
const control = fs.mkdtempSync(path.join(os.tmpdir(), "seki-proof-control-"));
try {
  fs.cpSync(path.join(seki, "Seki"), path.join(control, "Seki"), { recursive: true });
  fs.copyFileSync(path.join(seki, "lakefile.toml"), path.join(control, "lakefile.toml"));
  fs.copyFileSync(path.join(seki, "lean-toolchain"), path.join(control, "lean-toolchain"));
  const hex = fs.readFileSync("experiments/e0-vs1/minimum_age.scb0.hex", "utf8");
  // IntLit: claimed type U8 (02), term IntLit (02), IntegerType U8 (00), 0x12.
  assert.equal(hex.replace(/\s+/gu, "").split("02020012").length, 2,
    "the threshold literal is not where the control expects it");
  const mutated = path.join(control, "mutated.hex");
  fs.writeFileSync(mutated, hex.replace(/\s+/gu, "").replace("02020012", "02020013"));
  execFileSync("node", ["tools/lean_bytes.mjs", mutated, "Seki.Proofs.MinimumAge",
    path.join(control, "Seki/Proofs/MinimumAgeBytes.lean")]);
  const refuted = spawnSync("lake", ["build", "Seki.Proofs.MinimumAge"],
    { cwd: control, encoding: "utf8" });
  assert.notEqual(refuted.status, 0,
    "the proof still holds for a kernel whose threshold is 19");
} finally {
  fs.rmSync(control, { recursive: true, force: true });
}

console.log(
  `lean_proof=verified lean=${lean.version}@${lean.commit.slice(0, 12)} ` +
  `e0_record_theorems=${theorems} e0_record_native_decide=${nativeDecides} ` +
  `seki_constants=${audited[1]} seki_native_decide=0 exact_bytes=bound ` +
  "admission=kernel-checked totality=proved negative_control=refuted");
