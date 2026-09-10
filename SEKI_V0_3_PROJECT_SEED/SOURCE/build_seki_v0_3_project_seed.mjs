import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const valueAfter = (name) => {
  const index = args.indexOf(name);
  return index < 0 ? undefined : args[index + 1];
};
const packName = "SEKI_V0_3_PROJECT_SEED";
const output = path.resolve(valueAfter("--out") ?? path.join(root, `out/${packName}.zip`));
const epoch = new Date("1980-01-01T00:00:00Z");
const acceptedSpecCommit = "65692f383d31b2d50d694f68133be578528b0710";
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");
const fileSha = (name) => sha(fs.readFileSync(name));
const run = (command, commandArgs, options = {}) => {
  const result = spawnSync(command, commandArgs, {encoding: "utf8", ...options});
  if (result.status !== 0)
    throw new Error(`${command} failed\n${result.stdout ?? ""}${result.stderr ?? ""}`);
  return (result.stdout ?? "").trim();
};
const copy = (source, target, mode = 0o644) => {
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.copyFileSync(source, target);
  fs.chmodSync(target, mode);
};
const write = (target, body, mode = 0o644) => {
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.writeFileSync(target, body);
  fs.chmodSync(target, mode);
};
const walk = (directory, prefix = "") =>
  fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    const relative = path.join(prefix, entry.name);
    return entry.isDirectory() ? walk(path.join(directory, entry.name), relative) : [relative];
  });

const sourceCommit = run("git", ["rev-parse", "HEAD"], {cwd: root});
if (run("git", ["status", "--porcelain"], {cwd: root}))
  throw new Error("Seki project seed requires a clean committed source tree");
run("make", ["--no-print-directory", "check-seki-v0-3-spec"], {cwd: root});
run("make", ["--no-print-directory", "check-seki-kiku-f0-acceptance"], {cwd: root});

const temp = fs.mkdtempSync(path.join(os.tmpdir(), "seki-project-seed-"));
const pack = path.join(temp, packName);
fs.mkdirSync(pack, {recursive: true});

const inputs = [
  ["docs/architecture/SEKI_V0_SPEC.md", "SPEC/SEKI_V0_SPEC.md"],
  ["docs/architecture/SEKI_V0_3_REVIEW.json", "CONTRACTS/SEKI_V0_3_REVIEW.json"],
  ["docs/architecture/SEKI_V0_3_KIKU_F0_ACCEPTANCE.md",
    "ACCEPTANCE/SEKI_V0_3_KIKU_F0_ACCEPTANCE.md"],
  ["docs/architecture/SEKI_V0_3_KIKU_F0_ACCEPTANCE.json",
    "ACCEPTANCE/SEKI_V0_3_KIKU_F0_ACCEPTANCE.json"],
  ["docs/architecture/SEKI_F0_INDEPENDENT_CONSUMER_REVIEW_REQUEST.md",
    "ACCEPTANCE/SEKI_F0_INDEPENDENT_CONSUMER_REVIEW_REQUEST.md"],
  ["docs/architecture/SEKI_F1_BOOTSTRAP_PLAN.md", "BOOTSTRAP/SEKI_F1_BOOTSTRAP_PLAN.md"],
  ["docs/architecture/SEKI_V0_2_SPEC.md", "HISTORY/SEKI_V0_2_SPEC.md"],
  ["docs/architecture/SEKI_V0_2_REVIEW.json", "HISTORY/SEKI_V0_2_REVIEW.json"],
  ["docs/architecture/FROGFISH_PROVED_KERNEL_LANGUAGE_V0_SPEC.md",
    "HISTORY/FROGFISH_PROVED_KERNEL_LANGUAGE_V0_SPEC.md"],
  ["docs/architecture/FROGFISH_PROVED_KERNEL_LANGUAGE_V0_1_REVIEW.json",
    "HISTORY/FROGFISH_PROVED_KERNEL_LANGUAGE_V0_1_REVIEW.json"],
  ["tests/check_seki_v0_3_spec.mjs", "SOURCE_GATES/check_seki_v0_3_spec.mjs"],
  ["tests/check_seki_kiku_f0_acceptance.mjs",
    "SOURCE_GATES/check_seki_kiku_f0_acceptance.mjs"],
  ["scripts/build_seki_v0_3_project_seed.mjs",
    "SOURCE/build_seki_v0_3_project_seed.mjs"]
];
for (const [source, target] of inputs) copy(path.join(root, source), path.join(pack, target));

write(path.join(pack, "START_HERE.md"), `# Seki / 関 project seed

This archive contains the frozen design inputs required to create a separate
Seki implementation repository.

Normative language identity: \`io.frogfish.seki/language@0\`  
Normative revision: \`0.3\`  
Accepted specification commit: \`${acceptedSpecCommit}\`  
Seed assembly source commit: \`${sourceCommit}\`

Start with:

1. \`SPEC/SEKI_V0_SPEC.md\`;
2. \`CONTRACTS/SEKI_V0_3_REVIEW.json\`;
3. \`BOOTSTRAP/SEKI_F1_BOOTSTRAP_PLAN.md\`; and
4. \`ACCEPTANCE/SEKI_F0_INDEPENDENT_CONSUMER_REVIEW_REQUEST.md\`.

Kiku has accepted the charter. Global F0 is still open pending one materially
different consumer. This archive grants no implementation, proof, product,
native-binary or production authority.

Run \`./VERIFY.sh\` before importing any file into the new repository.
`);

write(path.join(pack, "SOURCE_IDENTITY.json"), `${JSON.stringify({
  schema: "io.frogfish.seki/project-seed-source@1",
  language_identity: "io.frogfish.seki/language@0",
  revision: "0.3",
  accepted_specification_commit: acceptedSpecCommit,
  seed_assembly_source_commit: sourceCommit,
  kiku_f0_review: "accepted",
  independent_consumer_f0_review: "pending",
  global_f0: "open",
  implementation_authority: false,
  proof_authority: false,
  product_authority: false
}, null, 2)}\n`);

write(path.join(pack, "THIRD_PARTY_BOUNDARIES.md"), `# Third-party boundaries

Seki v0.3 pins Lean 4.30.0, Rocq 9.2.0 and CompCert 3.18 as formal foundations.
This seed does not contain or license those projects.

The new project must bind exact dependency sources and review every license
before downloading, vendoring, redistributing or using a dependency in a
commercial product. In particular, do not assume that the public CompCert
distribution grants unrestricted commercial redistribution or use.

The native C compiler, assembler, linker, runtime and platform remain explicit
trusted premises in the initial profile unless a later qualified profile
removes them.
`);

write(path.join(pack, "VERIFY.mjs"), `import crypto from "node:crypto";
import fs from "node:fs";
const read = (p) => fs.readFileSync(new URL(p, import.meta.url), "utf8");
const expect = (v, m) => { if (!v) throw new Error(\`Seki seed: \${m}\`); };
const source = JSON.parse(read("SOURCE_IDENTITY.json"));
const contract = JSON.parse(read("CONTRACTS/SEKI_V0_3_REVIEW.json"));
const acceptance = JSON.parse(read("ACCEPTANCE/SEKI_V0_3_KIKU_F0_ACCEPTANCE.json"));
const spec = read("SPEC/SEKI_V0_SPEC.md");
const plan = read("BOOTSTRAP/SEKI_F1_BOOTSTRAP_PLAN.md");
expect(source.language_identity === "io.frogfish.seki/language@0", "source identity drift");
expect(source.accepted_specification_commit === "${acceptedSpecCommit}", "accepted commit drift");
expect(source.kiku_f0_review === "accepted" && source.global_f0 === "open", "F0 state drift");
expect(source.implementation_authority === false && source.proof_authority === false &&
  source.product_authority === false, "seed grants authority");
expect(contract.schema === "io.frogfish.seki/spec-review@0.3" &&
  contract.disposition === "seki_v0_3_revision_ready_for_f0_review", "contract drift");
expect(contract.cross_foundation_profile.scope ===
  "one-concrete-authority-bearing-invocation", "bridge scope drift");
expect(contract.cross_foundation_profile.universal_lean_rocq_equality_claimed === false,
  "universal bridge claim introduced");
expect(acceptance.decision === "accepted_seki_v0_3_for_f0" &&
  acceptance.global_f0_closed === false, "consumer/global F0 state conflated");
expect(spec.includes("### F4 — Generator refinement") &&
  spec.includes("Without the exact joint certificate receipt, no Lean-equivalence claim"),
  "normative F4 scope missing");
expect(plan.includes("Seki F1 project bootstrap plan") &&
  plan.includes("seki_f1_implementation_authorized"), "bootstrap plan incomplete");
const sums = read("SHA256SUMS").trim().split("\\n");
expect(sums.length >= 17, "manifest unexpectedly small");
console.log("seki_project_seed=verified revision=0.3 kiku=accepted global_f0=open authority=none");
`);

write(path.join(pack, "VERIFY.sh"), `#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$root"
shasum -a 256 -c SHA256SUMS
node VERIFY.mjs
`, 0o755);

let files = walk(pack).sort();
write(path.join(pack, "SHA256SUMS"),
  `${files.map((name) => `${fileSha(path.join(pack, name))}  ${name}`).join("\n")}\n`);
files = walk(pack).sort();
for (const name of files) {
  const target = path.join(pack, name);
  fs.utimesSync(target, epoch, epoch);
  fs.chmodSync(target, name === "VERIFY.sh" ? 0o755 : 0o644);
}

fs.mkdirSync(path.dirname(output), {recursive: true});
fs.rmSync(output, {force: true});
run("zip", ["-X", "-q", output, ...files.map((name) => path.join(packName, name))],
  {cwd: temp});
const archiveSha = fileSha(output);
fs.writeFileSync(`${output}.sha256`, `${archiveSha}  ${path.basename(output)}\n`);

const extracted = path.join(temp, "extracted");
fs.mkdirSync(extracted);
run("unzip", ["-q", output, "-d", extracted]);
run("./VERIFY.sh", [], {cwd: path.join(extracted, packName)});
fs.rmSync(temp, {recursive: true, force: true});

console.log(JSON.stringify({
  output,
  sha256: archiveSha,
  pack: packName,
  files: files.length,
  accepted_specification_commit: acceptedSpecCommit,
  seed_assembly_source_commit: sourceCommit,
  global_f0: "open",
  authority: "none"
}, null, 2));
