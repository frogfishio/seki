import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/*
 * Assembles a consumer bundle and verifies the three properties that make it a
 * bundle rather than a directory: it verifies itself, it detects tampering,
 * and assembling it twice produces the same manifest digest.
 */

const example = "spec/language/examples/access_permit.seki";
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-bundle-"));

const assemble = (into, environment) => {
  fs.mkdirSync(into, { recursive: true });
  execFileSync("node", ["tools/make_bundle.mjs", example, into],
    { stdio: "pipe", env: { ...process.env, ...environment } });
  return path.join(into, "seki-bundle-access_permit");
};

try {
  const bundle = assemble(path.join(temporary, "first"), {});

  // The bundle carries what a consumer integrates against, not a repository.
  for (const required of [
    "MANIFEST.json", "VERIFY.sh", "HOST-BOUNDARY-CONTRACT.md",
    "kernel/access_permit.seki", "kernel/access_permit.scb0",
    "kernel/access_permit.c", "kernel/seki_a0_access_permit.h",
    "kernel/TAGS.json", "compiler/sekic.c", "compiler/seki_c_backend.c",
  ]) {
    assert.ok(fs.existsSync(path.join(bundle, required)),
      `bundle is missing ${required}`);
  }

  const manifest = JSON.parse(
    fs.readFileSync(path.join(bundle, "MANIFEST.json"), "utf8"));
  assert.equal(manifest.decision_abi_revision, 2);
  assert.equal(manifest.host_boundary_contract_revision, 2);
  // The bundle states its own ceiling rather than leaving a reader to assume.
  assert.match(manifest.claim_ceiling, /not proved/u);
  assert.match(manifest.claim_ceiling, /no\n?\s*implementation, proof, product or production authority/u);

  // The tag dictionary reports authored stable tags, and the precedence a
  // failing premise counts against.
  const tags = JSON.parse(
    fs.readFileSync(path.join(bundle, "kernel/TAGS.json"), "utf8"));
  assert.equal(tags.reserved_rejection_tag, 0);
  assert.deepEqual(tags.rejections, {
    UnknownAccount: 1, StaleEpoch: 2, Underage: 3, TierTooLow: 7,
  });
  assert.deepEqual(tags.rejection_precedence, [1, 2, 3, 7]);

  // It verifies itself: digests match, the compiler rebuilds from the carried
  // sources, and that rebuild reproduces these artifacts byte for byte.
  const verified = spawnSync("./VERIFY.sh", [],
    { cwd: bundle, encoding: "utf8" });
  assert.equal(verified.status, 0, verified.stderr);
  assert.match(verified.stdout, /bundle verified/u);

  // Verification leaves the bundle as it found it, so it can be run again.
  const repeated = spawnSync("./VERIFY.sh", [],
    { cwd: bundle, encoding: "utf8" });
  assert.equal(repeated.status, 0, "verification is not repeatable");

  // It detects tampering with any carried file.
  const kernel = path.join(bundle, "kernel/access_permit.c");
  const original = fs.readFileSync(kernel);
  fs.appendFileSync(kernel, "\n/* tampered */\n");
  const tampered = spawnSync("./VERIFY.sh", [],
    { cwd: bundle, encoding: "utf8" });
  assert.equal(tampered.status, 1, "a tampered bundle verified");
  assert.match(tampered.stdout, /DIGEST MISMATCH kernel\/access_permit\.c/u);
  fs.writeFileSync(kernel, original);

  // Assembling twice produces the same manifest digest, under a different
  // locale and timezone.
  const second = assemble(path.join(temporary, "second"),
    { TZ: "Asia/Tokyo", LC_ALL: "tr_TR.UTF-8" });
  const secondManifest = JSON.parse(
    fs.readFileSync(path.join(second, "MANIFEST.json"), "utf8"));
  assert.equal(secondManifest.files_digest, manifest.files_digest,
    "the bundle is not reproducible");

  console.log(
    `seki_bundle=verified files=${Object.keys(manifest.files).length} ` +
    `digest=${manifest.files_digest.slice(0, 12)} reproducible=yes ` +
    "tamper_detected=yes self_verifying=yes");
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
