import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/*
 * The host-boundary contract states a mechanical surface a consumer integrates
 * against. This checks those statements against what the compiler actually
 * emits, so the contract cannot drift from the compiler without failing here.
 *
 * It deliberately does not try to check the prose in sections 1 and 2. Those
 * are assertions about what Seki does not do, and no test establishes them;
 * they are kept honest by review.
 */

const contractPath = "docs/alpha/HOST_BOUNDARY_CONTRACT.md";
const contract = fs.readFileSync(contractPath, "utf8");
const example = "spec/language/examples/access_permit.seki";
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-host-"));
const compiler = path.join(temporary, "sekic");
const sources = [
  "src/alpha/sekic.c", "src/alpha/seki_lexer.c", "src/alpha/seki_parser.c",
  "src/alpha/seki_types.c", "src/alpha/seki_checker.c",
  "src/alpha/seki_core.c", "src/alpha/seki_c_backend.c",
];

const stated = (label, pattern) => {
  const found = pattern.exec(contract);
  assert.ok(found !== null, `${contractPath} no longer states ${label}`);
  return found[1];
};

try {
  execFileSync("cc", ["-std=c11", "-pedantic", "-Werror", "-Isrc/alpha",
    ...sources, "-o", compiler], { stdio: "inherit" });

  // The contract's own revision numbers must match the compiler's.
  const abiRevision = stated("its decision ABI revision",
    /^- Decision ABI revision: (\d+)$/mu);
  const contractRevision = stated("its own revision",
    /^- Contract revision: (\d+)$/mu);
  assert.match(fs.readFileSync("src/alpha/seki_c_backend.c", "utf8"),
    new RegExp(`#define SEKI_DECISION_ABI_REVISION ${abiRevision}U`, "u"),
    "the contract and the compiler disagree about the ABI revision");
  assert.equal(contractRevision, "1");

  const core = path.join(temporary, "example.scb0");
  const generated = path.join(temporary, "example.c");
  const built = spawnSync(compiler,
    ["build", "--core", core, "--c", generated, example],
    { encoding: "utf8" });
  assert.equal(built.status, 0, built.stderr);
  const c = fs.readFileSync(generated, "utf8");

  // Section 4: the decision's first four fields, in order, with these types.
  assert.match(c, new RegExp(
    "typedef struct \\{\\n" +
    "    uint32_t abi_revision;\\n" +
    "    uint32_t disposition;[^\\n]*\\n" +
    "    uint32_t rejection_tag;[^\\n]*\\n" +
    "    uint32_t premise_tag;[^\\n]*\\n", "u"),
    "the decision's leading fields no longer match the contract");
  assert.match(c,
    new RegExp(`result\\.abi_revision = UINT32_C\\(${abiRevision}\\);`, "u"));

  // Section 4: the decision is zeroed before any field is written.
  assert.match(c, /_zero\(\(uint8_t \*\)&result, \(uint32_t\)sizeof result\);/u,
    "the decision is no longer zeroed, so padding is not deterministic");

  // Section 3: parameter passing and the stated identifier spellings.
  assert.match(c,
    /seki_a0_access_permit_decision\nseki_a0_access_permit_authorise\(seki_a0_access_permit_request seki_p_request\)/u,
    "the parameter-passing convention no longer matches the contract");
  assert.match(c, /uint8_t seki_f_age;/u);
  assert.match(c, /seki_a0_access_permit_accountid seki_f_account;/u);

  // Section 3: fields appear in canonical order, not source order. Checked
  // per struct, so every emitted record and payload is covered rather than
  // one chosen by hand. The example declares its request fields as account,
  // boundAccount, device, epoch, currentEpoch, age, tier, nonce.
  let structs = 0;
  for (const block of c.matchAll(/typedef struct \{\n([^}]*)\} (\w+);/gu)) {
    const fields = [...block[1].matchAll(/ seki_f_(\w+)(?:\[\d+\])?;/gu)]
      .map((match) => match[1]);
    if (fields.length < 2) {
      continue;
    }
    structs += 1;
    assert.deepEqual(fields, [...fields].sort(),
      `${block[2]} fields are not in canonical order`);
  }
  assert.ok(structs >= 2, "no multi-field struct was checked");

  // Section 4: stable tags are authored, not positional. The example declares
  // Underage @ 3 as its third case and TierTooLow @ 7 as its fourth.
  assert.match(c, /result\.rejection_tag = UINT32_C\(7\);/u,
    "rejection tags are no longer the authored stable tags");

  // Section 6: a failed build writes neither output.
  const rejectedSource = path.join(temporary, "rejected.seki");
  const rejectedCore = path.join(temporary, "rejected.scb0");
  const rejectedC = path.join(temporary, "rejected.c");
  fs.writeFileSync(rejectedSource,
    fs.readFileSync(example, "utf8").replace(">= 18", ">= 100000"));
  const rejected = spawnSync(compiler,
    ["build", "--core", rejectedCore, "--c", rejectedC, rejectedSource],
    { encoding: "utf8" });
  assert.notEqual(rejected.status, 0);
  assert.ok(!fs.existsSync(rejectedCore) && !fs.existsSync(rejectedC),
    "a failed build left an output behind");

  console.log(
    `host_boundary=verified contract=${contractRevision} ` +
    `abi=${abiRevision} authenticates=never canonical_fields=yes ` +
    "failed_build_writes=nothing");
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
