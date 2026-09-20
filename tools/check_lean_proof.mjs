import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";

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
 * `decodeExactProgram_eq` is discharged by `native_decide`, which evaluates
 * compiled Lean rather than checking a term in the kernel. Every theorem about
 * the decoded program rests on it, so Lean's compiler and runtime are trusted
 * premises here. The count is asserted so that adding another one is a visible
 * change rather than a quiet widening of the trusted base.
 */
const source = fs.readFileSync(proof, "utf8");
const nativeDecides = (source.match(/\bnative_decide\b/gu) ?? []).length;
assert.equal(nativeDecides, 1,
  `expected exactly one native_decide, found ${nativeDecides}`);
const theorems = (source.match(/^theorem /gmu) ?? []).length;
assert.ok(!/\bsorry\b/u.test(source), "the proof contains sorry");
assert.ok(!/^axiom /mu.test(source), "the proof declares an axiom");

console.log(
  `lean_proof=verified lean=${lean.version}@${lean.commit.slice(0, 12)} ` +
  `theorems=${theorems} sorry=0 axioms=0 native_decide=${nativeDecides}`);
