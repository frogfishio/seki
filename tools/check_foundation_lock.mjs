import assert from "node:assert/strict";
import fs from "node:fs";

const lock = JSON.parse(fs.readFileSync("foundations/FOUNDATION_LOCK.json", "utf8"));
const record = fs.readFileSync("docs/foundations/FORMAL_FOUNDATION_ACQUISITION.md", "utf8");

assert.equal(lock.schema, "io.frogfish.seki/formal-foundation-lock@0");
assert.equal(lock.status, "bootstrap-source-identities-bound");
assert.equal(lock.archives_vendored, false);

const { lean, rocq, compcert } = lock.foundations;
assert.equal(lean.version, "4.30.0");
assert.equal(lean.tag, "v4.30.0");
assert.equal(lean.primary_license, "Apache-2.0");
assert.equal(lean.installed_for_qualification, false);
assert.equal(rocq.version, "9.2.0");
assert.equal(rocq.tag, "V9.2.0");
assert.equal(rocq.primary_license, "LGPL-2.1-only");
assert.equal(rocq.bundled_component_licenses_present, true);
assert.equal(rocq.installed_for_qualification, false);
assert.equal(compcert.version, "3.18");
assert.equal(compcert.tag, "v3.18");
assert.equal(compcert.archive_version_file, "3.17");
assert.equal(compcert.archive_version_discrepancy, true);
assert.equal(compcert.installed_for_qualification, false);

for (const foundation of [lean, rocq, compcert]) {
  assert.match(foundation.commit, /^[0-9a-f]{40}$/u);
  assert.match(foundation.archive_sha256, /^[0-9a-f]{64}$/u);
  assert.match(foundation.license_sha256, /^[0-9a-f]{64}$/u);
  assert.ok(Number.isSafeInteger(foundation.archive_length));
  assert.ok(foundation.archive_length > 0);
  assert.match(foundation.archive_url, /^https:\/\//u);
}

assert.match(record, /do not vendor or\n   redistribute the full CompCert archive/u);
assert.match(record, /CompCert is a user-supplied formal foundation/u);
assert.match(record, /contains `version=3\.17`/u);
assert.match(record, /does not claim that the foundations are installed/u);

for (const value of Object.values(lock.claims)) assert.equal(value, false);

console.log(
  `foundation_lock=verified lean=${lean.version}@${lean.commit.slice(0, 12)} ` +
  `rocq=${rocq.version}@${rocq.commit.slice(0, 12)} ` +
  `compcert=${compcert.version}@${compcert.commit.slice(0, 12)} ` +
  "installed=false qualified=false",
);
