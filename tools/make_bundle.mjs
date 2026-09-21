import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

/*
 * Assembles one consumer bundle for one kernel.
 *
 * The bundle is what a consumer receives instead of a repository: the exact
 * compiler sources that produced the artifacts, the typed core, the generated
 * C and its public header, the tag dictionary a shadow oracle compares
 * against, the frozen host-boundary contract, and a manifest binding every one
 * of them by SHA-256.
 *
 * It is reproducible: assembling twice from the same inputs produces the same
 * manifest digest. Nothing in it depends on the working directory, the wall
 * clock or the order the filesystem happens to enumerate.
 *
 *   node tools/make_bundle.mjs KERNEL.seki OUTPUT-DIR
 */

const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");

const COMPILER_SOURCES = [
  "src/alpha/sekic.c", "src/alpha/seki_lexer.c", "src/alpha/seki_lexer.h",
  "src/alpha/seki_parser.c", "src/alpha/seki_parser.h",
  "src/alpha/seki_types.c", "src/alpha/seki_types.h",
  "src/alpha/seki_checker.c", "src/alpha/seki_checker.h",
  "src/alpha/seki_core.c", "src/alpha/seki_core.h",
  "src/alpha/seki_c_backend.c", "src/alpha/seki_c_backend.h",
];

const STRICT_FLAGS = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wstrict-prototypes",
  "-Wmissing-prototypes", "-Wundef", "-Wformat=2",
];

const [kernelSource, outputDirectory] = process.argv.slice(2);
if (kernelSource === undefined || outputDirectory === undefined) {
  process.stderr.write("usage: make_bundle.mjs KERNEL.seki OUTPUT-DIR\n");
  process.exit(64);
}

const moduleName = path.basename(kernelSource, ".seki");
const staging = `${outputDirectory}/seki-bundle-${moduleName}`;
fs.rmSync(staging, { recursive: true, force: true });
for (const directory of ["kernel", "compiler"]) {
  fs.mkdirSync(`${staging}/${directory}`, { recursive: true });
}

// Build the compiler from exactly the sources the bundle carries.
const compiler = `${staging}/sekic`;
execFileSync("cc", [...STRICT_FLAGS, "-Isrc/alpha",
  ...COMPILER_SOURCES.filter((name) => name.endsWith(".c")),
  "-o", compiler], { stdio: "inherit" });

const core = `${staging}/kernel/${moduleName}.scb0`;
const generated = `${staging}/kernel/${moduleName}.c`;
const header = `${staging}/kernel/seki_a0_${moduleName}.h`;
const built = spawnSync(compiler, ["build", "--core", core, "--c", generated,
  "--header", header, kernelSource], { encoding: "utf8" });
if (built.status !== 0) {
  process.stderr.write(built.stderr);
  process.exit(built.status ?? 70);
}
fs.copyFileSync(kernelSource, `${staging}/kernel/${moduleName}.seki`);

// The tag dictionary: what a shadow oracle compares a rejection against.
// Derived from the typed core rather than the source, so it reports what the
// artifact actually says.
const { decodeModule } = await import("../tools/encoding/decode_scb0.mjs");
const { checkTypedCore } = await import("../tools/encoding/check_typed_core.mjs");
const decoded = decodeModule(fs.readFileSync(core));
checkTypedCore(decoded);
const kernelBody = decoded.kernels[0][1];
const rejectionType = kernelBody.result[2];
const rejectionIndex = rejectionType[1][1];
const rejectionCases = decoded.types[rejectionIndex][1].body;
const tags = {
  schema: "io.frogfish.seki/tag-dictionary@1",
  module: decoded.identity[0].join("::"),
  kernel: decoded.kernels[0][0][0],
  decision_abi_revision: 2,
  disposition: { accepted: 1, rejected: 2 },
  reserved_rejection_tag: 0,
  // Precedence order is the kernel's declared order, which is what
  // `premise_tag` counts and what a failing premise reports.
  rejection_precedence: kernelBody.rejectionOrder.map(([, tag]) => tag),
  rejections: Object.fromEntries(rejectionCases.map(
    ([tag, body]) => [body.name, tag])),
};
fs.writeFileSync(`${staging}/kernel/TAGS.json`,
  `${JSON.stringify(tags, null, 2)}\n`);

for (const name of COMPILER_SOURCES) {
  fs.copyFileSync(name, `${staging}/compiler/${path.basename(name)}`);
}
fs.copyFileSync("docs/alpha/HOST_BOUNDARY_CONTRACT.md",
  `${staging}/HOST-BOUNDARY-CONTRACT.md`);
fs.writeFileSync(`${staging}/VERIFY.sh`, [
  "#!/bin/sh",
  "# Independently verify this bundle:",
  "#   1. every file matches the digest the manifest records;",
  "#   2. the compiler rebuilds from the sources carried here; and",
  "#   3. that compiler reproduces the kernel artifacts byte for byte.",
  "# Leaves the bundle exactly as it found it.",
  "set -eu",
  "",
  'work=$(mktemp -d)',
  'trap \'rm -rf "$work"\' EXIT',
  "",
  'echo "checking manifest digests"',
  "python3 - <<'PY'",
  "import hashlib, json, sys",
  'manifest = json.load(open("MANIFEST.json"))',
  'bad = 0',
  'for name, want in sorted(manifest["files"].items()):',
  '    got = hashlib.sha256(open(name, "rb").read()).hexdigest()',
  '    if got != want:',
  '        print("DIGEST MISMATCH", name); bad += 1',
  'digest = hashlib.sha256(json.dumps(',
  '    manifest["files"], separators=(",", ":")).encode()).hexdigest()',
  'if digest != manifest["files_digest"]:',
  '    print("MANIFEST DIGEST MISMATCH"); bad += 1',
  'print("files verified:", len(manifest["files"]))',
  'sys.exit(1 if bad else 0)',
  "PY",
  "",
  'echo "rebuilding the compiler from bundled sources"',
  `cc ${STRICT_FLAGS.join(" ")} -Icompiler compiler/*.c -o "$work/sekic"`,
  `"$work/sekic" build --core "$work/${moduleName}.scb0" \\`,
  `  --c "$work/${moduleName}.c" \\`,
  `  --header "$work/seki_a0_${moduleName}.h" kernel/${moduleName}.seki`,
  `cmp "$work/${moduleName}.scb0" kernel/${moduleName}.scb0`,
  `cmp "$work/${moduleName}.c" kernel/${moduleName}.c`,
  `cmp "$work/seki_a0_${moduleName}.h" kernel/seki_a0_${moduleName}.h`,
  "",
  'echo "compiling the generated kernel"',
  `cc ${STRICT_FLAGS.join(" ")} -Ikernel -c kernel/${moduleName}.c \\`,
  '  -o "$work/kernel.o"',
  "",
  'echo "bundle verified: digests match, rebuild reproduces, kernel compiles"',
  "",
].join("\n"), { mode: 0o755 });

// The manifest binds every file by digest. Entries are sorted by path, so the
// manifest does not depend on filesystem enumeration order.
const files = [];
const walk = (directory) => {
  for (const entry of fs.readdirSync(directory).sort()) {
    const full = `${directory}/${entry}`;
    if (fs.statSync(full).isDirectory()) {
      walk(full);
    } else if (entry !== "MANIFEST.json" && entry !== "sekic") {
      files.push(full.slice(staging.length + 1));
    }
  }
};
walk(staging);

const manifest = {
  schema: "io.frogfish.seki/consumer-bundle@1",
  module: tags.module,
  kernel: tags.kernel,
  decision_abi_revision: 2,
  host_boundary_contract_revision: 1,
  claim_ceiling: "provisional bootstrap alpha; the generated C is not proved " +
    "to preserve the kernel's semantics, and this bundle carries no " +
    "implementation, proof, product or production authority",
  compiler_build_flags: STRICT_FLAGS,
  // The compiler binary is deliberately absent: it is platform specific, and
  // VERIFY.sh rebuilds it from the sources listed here, then checks that the
  // rebuild reproduces these artifacts byte for byte.
  files: Object.fromEntries(files.sort().map(
    (name) => [name, digest(fs.readFileSync(`${staging}/${name}`))])),
};
manifest.files_digest = digest(JSON.stringify(manifest.files));
fs.writeFileSync(`${staging}/MANIFEST.json`,
  `${JSON.stringify(manifest, null, 2)}\n`);
fs.rmSync(compiler, { force: true });

process.stdout.write(
  `seki_bundle=assembled module=${tags.module} files=${files.length} ` +
  `digest=${manifest.files_digest.slice(0, 16)}\n`);
