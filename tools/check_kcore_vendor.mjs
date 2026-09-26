import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

/*
 * Verifies that the vendored KCore core is exactly the pinned upstream copy
 * plus the patches recorded for it, that it obeys KCore's source policy, and,
 * when Lean is installed, that it builds and passes KCore's axiom audit.
 *
 * When a Krisis checkout at the pinned commit is available next to this
 * repository, every unpatched file is also compared with that commit directly.
 * Without one, the digests in the lock are the only reference, and the printed
 * line says so.
 */

const root = "vendor/kcore";
const lock = JSON.parse(fs.readFileSync(path.join(root, "UPSTREAM.json"), "utf8"));
const digest = (file) =>
  createHash("sha256").update(fs.readFileSync(file)).digest("hex");

// Every patch names a file, its patched digest, and an entry in PATCHES.md.
const patchesText = fs.readFileSync(path.join(root, "PATCHES.md"), "utf8");
const patched = new Map();
for (const patch of lock.patches) {
  assert.ok(lock.upstream_files[patch.file] !== undefined,
    `patch ${patch.id} names a file that is not vendored: ${patch.file}`);
  assert.ok(patchesText.includes(patch.id),
    `patch ${patch.id} is not described in PATCHES.md`);
  patched.set(patch.file, patch);
}

// Upstream files match the pin, or their recorded patch.
for (const [file, expected] of Object.entries(lock.upstream_files)) {
  const actual = digest(path.join(root, file));
  const patch = patched.get(file);
  assert.equal(actual, patch === undefined ? expected : patch.sha256,
    patch === undefined
      ? `vendored ${file} differs from the pinned upstream copy`
      : `vendored ${file} differs from patch ${patch.id}`);
}

// Nothing else is in the tree except declared Seki glue and build output.
const declared = new Set([
  ...Object.keys(lock.upstream_files), ...lock.local_files]);
const walk = (directory) => fs.readdirSync(directory, { withFileTypes: true })
  .flatMap((entry) => {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      return entry.name === ".lake" ? [] : walk(full);
    }
    return [path.relative(root, full)];
  });
for (const file of walk(root)) {
  assert.ok(declared.has(file) || path.basename(file) === ".DS_Store",
    `undeclared file in the vendored tree: ${file}`);
}

// KCore's own source policy, applied to the copy.
const leanSources = Object.keys(lock.upstream_files)
  .filter((file) => file.endsWith(".lean"))
  .concat(lock.local_files.filter((file) => file.endsWith(".lean")));
const forbidden = [
  [/\bsorry\b|\badmit\b/u, "sorry/admit"],
  [/^[ \t]*(private |protected )?axiom\b/mu, "user axiom"],
  [/\b(partial|unsafe)[ \t]+(def|abbrev|instance|opaque)\b/u,
    "partial/unsafe definition"],
  [/\bnative_decide\b|Lean\.ofReduceBool/u, "native decision"],
  [/@\[(extern|export)|implemented_by/u, "FFI attribute"],
];
for (const file of leanSources) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  for (const [pattern, description] of forbidden) {
    assert.ok(!pattern.test(text), `${file}: policy violation: ${description}`);
  }
}

// Direct comparison with the pinned commit, when a checkout is at hand.
let crossChecked = "skipped";
const upstream = path.resolve(lock.upstream.repository_hint);
const has = spawnSync("git",
  ["-C", upstream, "cat-file", "-e", `${lock.upstream.commit}^{commit}`]);
if (has.status === 0) {
  for (const file of Object.keys(lock.upstream_files)) {
    if (patched.has(file)) continue;
    const original = execFileSync("git",
      ["-C", upstream, "show", `${lock.upstream.commit}:${file}`]);
    assert.ok(original.equals(fs.readFileSync(path.join(root, file))),
      `vendored ${file} differs from ${file} at the pinned commit`);
  }
  crossChecked = "yes";
}

// Build and audit, when Lean is installed.
const formal = path.join(root, "formal/kcore");
assert.equal(fs.readFileSync(path.join(formal, "lean-toolchain"), "utf8").trim(),
  lock.lean_toolchain, "the vendored lean-toolchain differs from the lock");
let audit = "skipped";
const lake = spawnSync("lake", ["--version"], { encoding: "utf8" });
if (lake.error === undefined && lake.status === 0) {
  execFileSync("lake", ["build"], { cwd: formal, stdio: "pipe" });
  const output = execFileSync("lake", ["env", "lean", "Audit/Axioms.lean"],
    { cwd: formal, encoding: "utf8" });
  const constants = /kcore_axiom_audit=verified constants=(\d+)/u.exec(output);
  assert.ok(constants !== null, `axiom audit did not verify: ${output}`);
  audit = constants[1];
}

console.log(
  `kcore_vendor=verified commit=${lock.upstream.commit.slice(0, 7)} ` +
  `files=${Object.keys(lock.upstream_files).length} ` +
  `patches=${lock.patches.length} upstream_crosscheck=${crossChecked} ` +
  `axiom_audit_constants=${audit}`);
