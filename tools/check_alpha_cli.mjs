import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { decodeModule } from "./encoding/decode_scb0.mjs";
import { checkTypedCore } from "./encoding/check_typed_core.mjs";

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-a0-cli-"));
const compiler = path.join(temporary, "sekic");
const canonicalSource = "experiments/e0-vs1/minimum_age.seki";
// The typed core is still the E0 experiment's exact bytes: the semantic root
// did not move. The generated C is the alpha's own regression, because the
// decision ABI deliberately diverged from the closed experiment's two-octet
// result. E0's own artifacts stay frozen as experimental evidence.
const recordedCore = "experiments/e0-vs1/minimum_age.scb0.hex";
const recordedC = "tests/alpha/regression/minimum_age.generated.c";
const sources = [
  "src/alpha/sekic.c",
  "src/alpha/seki_lexer.c",
  "src/alpha/seki_parser.c",
  "src/alpha/seki_types.c",
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
    "sekic 0.0.0-alpha.6 (provisional, authority=none)\n");

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
    .replaceAll("Applicant", "Datum")
    .replaceAll("Rejection", "Denial")
    .replaceAll("Underage", "Below")
    .replaceAll("decide", "screen")
    .replaceAll("applicant", "signal")
    .replaceAll("age", "level")
    .replace("Below @ 1.", "Below @ 7.")
    .replace("  level: U8\n}.", "  code: U8,\n  level: U8\n}.")
    .replace("  Below @ 7.\n].", "  Other @ 3.\n  Below @ 7.\n].")
    .replace("rejects: Denial::Below",
      "rejects: Denial::Other, Denial::Below")
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
  // Every decision stamps the ABI revision a consumer reads first.
  assert.match(fs.readFileSync(cPath, "utf8"),
    /result\.abi_revision = UINT32_C\(2\);/u);

  const renamed = run([
    "build", "--core", renamedCore, "--c", renamedC, renamedSource,
  ]);
  assert.equal(renamed.status, 0, renamed.stderr);
  const renamedCText = fs.readFileSync(renamedC, "utf8");
  assert.match(renamedCText, /seki_a0_gate_policy_datum/u);
  assert.match(renamedCText, /seki_a0_gate_policy_screen/u);
  assert.match(renamedCText, /uint8_t seki_f_code;/u);
  assert.match(renamedCText, /uint8_t seki_f_level;/u);
  assert.match(renamedCText,
    /seki_p_signal\.seki_f_level < UINT8_C\(42\)/u);
  assert.match(renamedCText, /result\.rejection_tag = UINT32_C\(7\)/u);
  checkTypedCore(decodeModule(fs.readFileSync(renamedCore)));
  execFileSync("cc", [...strictFlags, "-c", renamedC, "-o",
    path.join(temporary, "gate_policy.o")], { stdio: "inherit" });

  // Every ordered comparison now lowers through the general emitter rather
  // than one hardcoded `less` shape.
  for (const [operator, expected] of [[">", 2], [">=", 3], ["<=", 1]]) {
    const operatorSource = path.join(temporary, `operator${expected}.seki`);
    const operatorCore = path.join(temporary, `operator${expected}.scb0`);
    const operatorC = path.join(temporary, `operator${expected}.c`);
    fs.writeFileSync(operatorSource,
      fs.readFileSync(canonicalSource, "utf8").replace("< 18", `${operator} 18`));
    const built = run([
      "build", "--core", operatorCore, "--c", operatorC, operatorSource,
    ]);
    assert.equal(built.status, 0, built.stderr);
    const decoded = decodeModule(fs.readFileSync(operatorCore));
    checkTypedCore(decoded);
    assert.equal(decoded.kernels[0][1].body[1].term[1], expected);
  }

  // Source order is a developer convenience: declaring the variant first must
  // produce exactly the canonical bytes, not a different module.
  const reorderedSource = path.join(temporary, "reordered.seki");
  const reorderedCore = path.join(temporary, "reordered.scb0");
  const reorderedC = path.join(temporary, "reordered.c");
  const canonicalText = fs.readFileSync(canonicalSource, "utf8");
  const recordBlock = "export record Applicant {\n  age: U8\n}.\n\n";
  const variantBlock = "export variant Rejection [\n  Underage @ 1.\n].\n\n";
  assert.ok(canonicalText.includes(recordBlock + variantBlock));
  fs.writeFileSync(reorderedSource,
    canonicalText.replace(recordBlock + variantBlock, variantBlock + recordBlock));
  const reordered = run([
    "build", "--core", reorderedCore, "--c", reorderedC, reorderedSource,
  ]);
  assert.equal(reordered.status, 0, reordered.stderr);
  assert.deepEqual(fs.readFileSync(reorderedCore), fs.readFileSync(corePath));

  // Canonical positions depend on the program's own identifiers. When the
  // variant name sorts before the record name the type table order flips, and
  // both directions must follow it rather than assuming a fixed 0/1 layout.
  const flippedSource = path.join(temporary, "flipped.seki");
  const flippedCore = path.join(temporary, "flipped.scb0");
  const flippedC = path.join(temporary, "flipped.c");
  fs.writeFileSync(flippedSource, canonicalText
    .replaceAll("Applicant", "Zeta").replaceAll("Rejection", "Alpha"));
  const flipped = run([
    "build", "--core", flippedCore, "--c", flippedC, flippedSource,
  ]);
  assert.equal(flipped.status, 0, flipped.stderr);
  const flippedDecoded = decodeModule(fs.readFileSync(flippedCore));
  checkTypedCore(flippedDecoded);
  assert.equal(flippedDecoded.types[0][0], "Alpha");
  assert.equal(flippedDecoded.types[1][0], "Zeta");
  execFileSync("cc", [...strictFlags, "-c", flippedC, "-o",
    path.join(temporary, "flipped.o")], { stdio: "inherit" });

  // The header vectors are general: a module stating one claim and one
  // obligation builds, where the backend previously required the exact
  // minimum-age lists.
  const minimalHeaderSource = path.join(temporary, "minimal-header.seki");
  const minimalHeaderCore = path.join(temporary, "minimal-header.scb0");
  const minimalHeaderC = path.join(temporary, "minimal-header.c");
  fs.writeFileSync(minimalHeaderSource, [
    "module probe @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record D { v: U8 }.",
    "export variant R [ Bad @ 1. ].",
    "export kernel k d: D -> Decision[Unit, R] arithmetic: checked",
    "bounded steps: 64 liveBits: 512 controlDepth: 32 workspaceBits: 0",
    "rejects: R::Bad publication: none [ (d v) < 18",
    "  ifTrue: [ reject R::Bad ] ifFalse: [ accept unit ] ].",
    "",
  ].join("\n"));
  const minimalHeader = run([
    "build", "--core", minimalHeaderCore, "--c", minimalHeaderC,
    minimalHeaderSource,
  ]);
  assert.equal(minimalHeader.status, 0, minimalHeader.stderr);
  checkTypedCore(decodeModule(fs.readFileSync(minimalHeaderCore)));
  execFileSync("cc", [...strictFlags, "-c", minimalHeaderC, "-o",
    path.join(temporary, "minimal-header.o")], { stdio: "inherit" });

  // Kernel control nests: a three-premise decision with ordered rejection
  // precedence compiles end to end, is revalidated by the independent semantic
  // checker, and is exhaustively compared against the policy it states.
  const nestedSource = path.join(temporary, "nested.seki");
  const nestedCore = path.join(temporary, "nested.scb0");
  const nestedC = path.join(temporary, "nested.c");
  fs.writeFileSync(nestedSource, [
    "module gate::nested @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Claim { age: U8, tier: U8 }.",
    "export variant Denial [ Underage @ 1. WrongTier @ 4. Blocked @ 9. ].",
    "",
    "export kernel screen claim: Claim",
    "-> Decision[Unit, Denial] arithmetic: checked",
    "bounded steps: 128 liveBits: 1024 controlDepth: 64 workspaceBits: 0",
    "rejects: Denial::Blocked, Denial::Underage, Denial::WrongTier",
    "publication: none [",
    "  (claim tier) == 0",
    "    ifTrue: [ reject Denial::Blocked ]",
    "    ifFalse: [ (claim age) < 18",
    "      ifTrue: [ reject Denial::Underage ]",
    "      ifFalse: [ (claim tier) > 3",
    "        ifTrue: [ reject Denial::WrongTier ]",
    "        ifFalse: [ accept unit ] ] ]",
    "].",
    "",
  ].join("\n"));
  const nested = run([
    "build", "--core", nestedCore, "--c", nestedC, nestedSource,
  ]);
  assert.equal(nested.status, 0, nested.stderr);
  const nestedDecoded = decodeModule(fs.readFileSync(nestedCore));
  checkTypedCore(nestedDecoded);
  // The C derivation of the cost algebra must agree with this module's stored
  // exact bounds, which the independent checker has just recomputed.
  assert.deepEqual(nestedDecoded.kernels[0][1].exact, [18, 40, 7, 0]);

  const nestedHarness = path.join(temporary, "nested_main.c");
  fs.writeFileSync(nestedHarness, [
    '#include <stdint.h>',
    '#include <stdio.h>',
    '#include "nested.c"',
    'int main(void) {',
    '    unsigned bad = 0U;',
    '    for (unsigned age = 0U; age < 256U; ++age)',
    '    for (unsigned tier = 0U; tier < 256U; ++tier) {',
    '        seki_a0_nested_claim c;',
    '        seki_a0_nested_decision got;',
    '        uint32_t wt, wr;',
    '        c.seki_f_age = (uint8_t)age; c.seki_f_tier = (uint8_t)tier;',
    '        got = seki_a0_nested_screen(c);',
    '        if (tier == 0U)     { wt = 2U; wr = 9U; }',
    '        else if (age < 18U) { wt = 2U; wr = 1U; }',
    '        else if (tier > 3U) { wt = 2U; wr = 4U; }',
    '        else                { wt = 1U; wr = 0U; }',
    '        if (got.disposition != wt || got.rejection_tag != wr) ++bad;',
    '        if (got.abi_revision != UINT32_C(2)) ++bad;',
    '    }',
    '    printf("%u\\n", bad);',
    '    return bad != 0U;',
    '}',
    '',
  ].join("\n"));
  const nestedExe = path.join(temporary, "nested_main");
  execFileSync("cc", [...strictFlags, "-fsanitize=address,undefined",
    `-I${temporary}`, nestedHarness, "-o", nestedExe], { stdio: "inherit" });
  assert.equal(execFileSync(nestedExe, { encoding: "utf8" }), "0\n");

  // Record fields carry their own unsigned width through both directions, and
  // an integer literal wider than one octet round-trips big-endian.
  const wideSource = path.join(temporary, "wide.seki");
  const wideCore = path.join(temporary, "wide.scb0");
  const wideC = path.join(temporary, "wide.c");
  fs.writeFileSync(wideSource, [
    "module gate::wide @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Meter { count: U32, level: U16 }.",
    "export variant Fault [ TooHigh @ 2. ].",
    "",
    "export kernel gauge meter: Meter",
    "-> Decision[Unit, Fault] arithmetic: checked",
    "bounded steps: 128 liveBits: 1024 controlDepth: 64 workspaceBits: 0",
    "rejects: Fault::TooHigh",
    "publication: none [ (meter count) > 70000",
    "  ifTrue: [ reject Fault::TooHigh ] ifFalse: [ accept unit ] ].",
    "",
  ].join("\n"));
  const wide = run(["build", "--core", wideCore, "--c", wideC, wideSource]);
  assert.equal(wide.status, 0, wide.stderr);
  const wideDecoded = decodeModule(fs.readFileSync(wideCore));
  checkTypedCore(wideDecoded);
  // IntLit(U32, 70000) occupies exactly four octets, most significant first.
  const wideLiteral = wideDecoded.kernels[0][1].body[1].term[3].term;
  assert.equal(wideLiteral[1], 2);
  assert.deepEqual([...wideLiteral[2]], [0x00, 0x01, 0x11, 0x70]);
  const wideText = fs.readFileSync(wideC, "utf8");
  assert.match(wideText, /uint32_t seki_f_count;/u);
  assert.match(wideText, /uint16_t seki_f_level;/u);
  assert.match(wideText, /seki_f_count > UINT32_C\(70000\)/u);
  execFileSync("cc", [...strictFlags, "-c", wideC, "-o",
    path.join(temporary, "wide.o")], { stdio: "inherit" });

  // A module may declare more than one record and one variant. Every declared
  // record becomes a struct in canonical order, and the kernel signature
  // selects which declarations it uses by position rather than by a fixed
  // layout: here the parameter record is second and the variant is last.
  const multiSource = path.join(temporary, "multi.seki");
  const multiCore = path.join(temporary, "multi.scb0");
  const multiC = path.join(temporary, "multi.c");
  fs.writeFileSync(multiSource, [
    "module grit::multi @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Artifact { epoch: U32 }.",
    "export record Candidate { pack: U32, vocabulary: U32 }.",
    "export variant Refusal [ PackMismatch @ 1. VocabularyMismatch @ 2. ].",
    "export record Receipt { issued: U8 }.",
    "",
    "export kernel publish candidate: Candidate",
    "-> Decision[Unit, Refusal] arithmetic: checked",
    "bounded steps: 128 liveBits: 1024 controlDepth: 64 workspaceBits: 0",
    "rejects: Refusal::PackMismatch, Refusal::VocabularyMismatch",
    "publication: none [",
    "  (candidate pack) != 7",
    "    ifTrue: [ reject Refusal::PackMismatch ]",
    "    ifFalse: [ (candidate vocabulary) != 3",
    "      ifTrue: [ reject Refusal::VocabularyMismatch ]",
    "      ifFalse: [ accept unit ] ]",
    "].",
    "",
  ].join("\n"));
  const multi = run(["build", "--core", multiCore, "--c", multiC, multiSource]);
  assert.equal(multi.status, 0, multi.stderr);
  const multiDecoded = decodeModule(fs.readFileSync(multiCore));
  checkTypedCore(multiDecoded);
  // Source order was Artifact, Candidate, Refusal, Receipt; the table is
  // ordered by name regardless.
  assert.deepEqual(multiDecoded.types.map(([name]) => name),
    ["Artifact", "Candidate", "Receipt", "Refusal"]);
  const multiText = fs.readFileSync(multiC, "utf8");
  for (const struct of ["artifact", "candidate", "receipt"]) {
    assert.ok(multiText.includes(`} seki_a0_multi_${struct};`),
      `missing struct seki_a0_multi_${struct}`);
  }
  // A variant contributes no struct of its own.
  assert.ok(!multiText.includes("seki_a0_multi_refusal"));
  assert.match(multiText, /seki_a0_multi_publish\(seki_a0_multi_candidate /u);
  execFileSync("cc", [...strictFlags, "-c", multiC, "-o",
    path.join(temporary, "multi.o")], { stdio: "inherit" });

  // `Digest` and `Bytes` fields project to octet arrays, and identity
  // comparison runs in time independent of the first differing octet: these
  // are authenticated evidence identities, so an early-exit comparison would
  // leak how much of a candidate identity an attacker had guessed.
  const digestSource = path.join(temporary, "digest.seki");
  const digestCore = path.join(temporary, "digest.scb0");
  const digestC = path.join(temporary, "digest.c");
  fs.writeFileSync(digestSource, [
    "module grit::identity @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Handoff {",
    "  declared: Digest[sha256, 32],",
    "  observed: Digest[sha256, 32]",
    "}.",
    "export variant Refusal [ IdentityMismatch @ 1. ].",
    "",
    "export kernel publish handoff: Handoff",
    "-> Decision[Unit, Refusal] arithmetic: checked",
    "bounded steps: 128 liveBits: 4096 controlDepth: 64 workspaceBits: 0",
    "rejects: Refusal::IdentityMismatch",
    "publication: none [ (handoff declared) != (handoff observed)",
    "  ifTrue: [ reject Refusal::IdentityMismatch ] ifFalse: [ accept unit ] ].",
    "",
  ].join("\n"));
  const digest = run([
    "build", "--core", digestCore, "--c", digestC, digestSource,
  ]);
  assert.equal(digest.status, 0, digest.stderr);
  const digestDecoded = decodeModule(fs.readFileSync(digestCore));
  checkTypedCore(digestDecoded);
  assert.deepEqual(digestDecoded.kernels[0][1].exact, [9, 1536, 5, 0]);
  const digestText = fs.readFileSync(digestC, "utf8");
  assert.match(digestText, /uint8_t seki_f_declared\[32\];/u);
  assert.match(digestText, /difference \|= \(uint8_t\)\(left\[index\]/u);
  assert.match(digestText, /!seki_a0_identity_octets_equal\(/u);
  execFileSync("cc", [...strictFlags, "-c", digestC, "-o",
    path.join(temporary, "digest.o")], { stdio: "inherit" });

  // Ordered comparison on an octet array has no C operator form; the checker
  // must reject it before the projection is asked to print one.
  const digestOrdered = path.join(temporary, "digest-ordered.seki");
  fs.writeFileSync(digestOrdered,
    fs.readFileSync(digestSource, "utf8").replace("!=", "<"));
  const ordered = run(["check", digestOrdered]);
  assert.equal(ordered.status, 65);
  assert.match(ordered.stderr,
    /^A0-CHECK-0004:.*ordered comparison requires numeric operands\n$/u);

  // Short-circuit Boolean operators, with `&&` binding tighter than `||`.
  const boolSource = path.join(temporary, "bool.seki");
  const boolCore = path.join(temporary, "bool.scb0");
  const boolC = path.join(temporary, "bool.c");
  fs.writeFileSync(boolSource, [
    "module gate::bool @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Entry { age: U8, tier: U8, region: U8 }.",
    "export variant Denial [ NotEligible @ 1. ].",
    "",
    "export kernel screen entry: Entry",
    "-> Decision[Unit, Denial] arithmetic: checked",
    "bounded steps: 256 liveBits: 2048 controlDepth: 64 workspaceBits: 0",
    "rejects: Denial::NotEligible",
    "publication: none [",
    "  (entry age) < 18 || (entry tier) == 0 && (entry region) != 7",
    "    ifTrue: [ reject Denial::NotEligible ] ifFalse: [ accept unit ] ].",
    "",
  ].join("\n"));
  const booleans = run(["build", "--core", boolCore, "--c", boolC, boolSource]);
  assert.equal(booleans.status, 0, booleans.stderr);
  const boolDecoded = decodeModule(fs.readFileSync(boolCore));
  checkTypedCore(boolDecoded);
  const boolCondition = boolDecoded.kernels[0][1].body[1].term;
  // `||` is the root and `&&` its right child: precedence, not source order.
  assert.equal(boolCondition[0], 18);
  assert.equal(boolCondition[2].term[0], 17);
  assert.deepEqual(boolDecoded.kernels[0][1].exact, [18, 56, 7, 0]);
  // The printed C groups explicitly rather than relying on C precedence.
  assert.match(fs.readFileSync(boolC, "utf8"),
    /< UINT8_C\(18\) \|\| \(.* && .*\)\) \{/u);
  execFileSync("cc", [...strictFlags, "-c", boolC, "-o",
    path.join(temporary, "bool.o")], { stdio: "inherit" });

  // A non-Boolean operand is rejected before any artifact is constructed.
  const boolBad = path.join(temporary, "bool-bad.seki");
  fs.writeFileSync(boolBad, fs.readFileSync(boolSource, "utf8")
    .replace("(entry tier) == 0", "(entry tier)"));
  const boolBadRun = run(["check", boolBad]);
  assert.equal(boolBadRun.status, 65);
  assert.match(boolBadRun.stderr, /^A0-CHECK-0018:/u);

  // Nominal types are not substitutable even when they share a representation,
  // which is the property a handoff needs from distinct evidence identities.
  const nominalSource = path.join(temporary, "nominal.seki");
  const nominalCore = path.join(temporary, "nominal.scb0");
  const nominalC = path.join(temporary, "nominal.c");
  fs.writeFileSync(nominalSource, [
    "module grit::identity @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export nominal ArtifactId := Digest[sha256, 32].",
    "export nominal PackId := Digest[sha256, 32].",
    "",
    "export record Handoff {",
    "  artifact: ArtifactId, expected: ArtifactId, pack: PackId",
    "}.",
    "export variant Refusal [ ArtifactMismatch @ 1. ].",
    "",
    "export kernel publish handoff: Handoff",
    "-> Decision[Unit, Refusal] arithmetic: checked",
    "bounded steps: 128 liveBits: 8192 controlDepth: 64 workspaceBits: 0",
    "rejects: Refusal::ArtifactMismatch",
    "publication: none [ (handoff artifact) != (handoff expected)",
    "  ifTrue: [ reject Refusal::ArtifactMismatch ] ifFalse: [ accept unit ] ].",
    "",
  ].join("\n"));
  const nominal = run([
    "build", "--core", nominalCore, "--c", nominalC, nominalSource,
  ]);
  assert.equal(nominal.status, 0, nominal.stderr);
  const nominalDecoded = decodeModule(fs.readFileSync(nominalCore));
  checkTypedCore(nominalDecoded);
  // A typedef must precede its use, so declarations follow the module's own
  // dependency order rather than canonical name order.
  assert.deepEqual(nominalDecoded.derivations.typeOrder, [0, 2, 1, 3]);
  const nominalText = fs.readFileSync(nominalC, "utf8");
  assert.ok(nominalText.indexOf("} seki_a0_identity_handoff;") >
    nominalText.indexOf("typedef uint8_t seki_a0_identity_artifactid[32];"),
    "a typedef was emitted after the struct that uses it");
  // An octet array reached through a nominal is still an octet array.
  // Comparing two of them with a C operator would compare addresses, always
  // differ, and reject every input.
  assert.match(nominalText,
    /!seki_a0_identity_octets_equal\(seki_p_handoff\.seki_f_artifact, /u);
  assert.ok(!/seki_f_artifact != seki_p_handoff/u.test(nominalText),
    "octet identities were compared as pointers");
  execFileSync("cc", [...strictFlags, "-c", nominalC, "-o",
    path.join(temporary, "nominal.o")], { stdio: "inherit" });

  // Two nominals over the same representation do not compare.
  const nominalSub = path.join(temporary, "nominal-sub.seki");
  fs.writeFileSync(nominalSub, fs.readFileSync(nominalSource, "utf8")
    .replace("(handoff expected)", "(handoff pack)"));
  const substituted = run(["check", nominalSub]);
  assert.equal(substituted.status, 65);
  assert.match(substituted.stderr,
    /^A0-CHECK-0004:.*comparison operands are incompatible\n$/u);

  // `require C else: V::Case.` states one premise and the rejection that
  // reports its failure, which is the natural form for a decision with several
  // premises in declared precedence order.
  const requireSource = path.join(temporary, "require.seki");
  const requireCore = path.join(temporary, "require.scb0");
  const requireC = path.join(temporary, "require.c");
  fs.writeFileSync(requireSource, [
    "module grit::publish @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Candidate { epoch: U32, pack: U32, tier: U8 }.",
    "export variant Refusal [ Stale @ 1. WrongPack @ 2. LowTier @ 3. ].",
    "",
    "export kernel publish candidate: Candidate",
    "-> Decision[Unit, Refusal] arithmetic: checked",
    "bounded steps: 256 liveBits: 2048 controlDepth: 64 workspaceBits: 0",
    "rejects: Refusal::Stale, Refusal::WrongPack, Refusal::LowTier",
    "publication: none [",
    "  require (candidate epoch) == 42 else: Refusal::Stale.",
    "  require (candidate pack) == 7 else: Refusal::WrongPack.",
    "  require (candidate tier) >= 3 else: Refusal::LowTier.",
    "  accept unit",
    "].",
    "",
  ].join("\n"));
  const required = run([
    "build", "--core", requireCore, "--c", requireC, requireSource,
  ]);
  assert.equal(required.status, 0, required.stderr);
  const requireDecoded = decodeModule(fs.readFileSync(requireCore));
  checkTypedCore(requireDecoded);
  // KernelRequire, not a chain of KernelIf.
  assert.equal(requireDecoded.kernels[0][1].body[0], 2);
  assert.deepEqual(requireDecoded.kernels[0][1].exact, [18, 176, 7, 0]);
  execFileSync("cc", [...strictFlags, "-c", requireC, "-o",
    path.join(temporary, "require.o")], { stdio: "inherit" });

  // `else` is a keyword part, not a field selector. The grammar distinguishes
  // them by the following colon, so a premise reading a field named `else`
  // would be the only way this could go wrong.
  const requireBad = path.join(temporary, "require-bad.seki");
  fs.writeFileSync(requireBad, fs.readFileSync(requireSource, "utf8")
    .replace("else: Refusal::Stale", "else: Refusal::Missing"));
  const requireBadRun = run(["check", requireBad]);
  assert.equal(requireBadRun.status, 65);
  assert.match(requireBadRun.stderr, /^A0-CHECK-0007:/u);

  // `name := expr.` binds one fresh immutable local whose scope is the rest of
  // the body. The encoding erases binding names, so each is spelled in C by
  // the order it was introduced and referenced by its environment slot.
  const letSource = path.join(temporary, "let.seki");
  const letCore = path.join(temporary, "let.scb0");
  const letC = path.join(temporary, "let.c");
  fs.writeFileSync(letSource, [
    "module gate::binding @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Entry { age: U8, tier: U8 }.",
    "export variant Denial [ TooYoung @ 1. TooLow @ 2. ].",
    "",
    "export kernel screen entry: Entry",
    "-> Decision[Unit, Denial] arithmetic: checked",
    "bounded steps: 256 liveBits: 2048 controlDepth: 64 workspaceBits: 0",
    "rejects: Denial::TooYoung, Denial::TooLow",
    "publication: none [",
    "  age := entry age.",
    "  tier := entry tier.",
    "  require age >= 18 else: Denial::TooYoung.",
    "  require tier >= 3 else: Denial::TooLow.",
    "  accept unit",
    "].",
    "",
  ].join("\n"));
  const bound = run(["build", "--core", letCore, "--c", letC, letSource]);
  assert.equal(bound.status, 0, bound.stderr);
  const letDecoded = decodeModule(fs.readFileSync(letCore));
  checkTypedCore(letDecoded);
  assert.equal(letDecoded.kernels[0][1].body[0], 3);
  assert.deepEqual(letDecoded.kernels[0][1].exact, [17, 49, 7, 0]);
  const letText = fs.readFileSync(letC, "utf8");
  // The second binding must read the second field, not the first: a slot
  // resolved one place off would still compile and still be wrong.
  assert.match(letText, /const uint8_t seki_b0 = seki_p_entry\.seki_f_age;/u);
  assert.match(letText, /const uint8_t seki_b1 = seki_p_entry\.seki_f_tier;/u);
  assert.match(letText, /!\(seki_b0 >= UINT8_C\(18\)\)/u);
  assert.match(letText, /!\(seki_b1 >= UINT8_C\(3\)\)/u);
  execFileSync("cc", [...strictFlags, "-c", letC, "-o",
    path.join(temporary, "let.o")], { stdio: "inherit" });

  // Locals are immutable and cannot shadow another visible local.
  const shadowSource = path.join(temporary, "shadow.seki");
  fs.writeFileSync(shadowSource, fs.readFileSync(letSource, "utf8")
    .replace("tier := entry tier.", "age := entry tier.")
    .replace("require tier >= 3", "require age >= 3"));
  const shadowed = run(["check", shadowSource]);
  assert.equal(shadowed.status, 65);
  assert.match(shadowed.stderr, /^A0-CHECK-0019:/u);

  // Acceptance can carry a value rather than `Unit`: the decision result holds
  // it, and a record literal builds it. The literal's own field order is free
  // because constructor fields are keyed by FieldRef and emitted canonically.
  const permitSource = path.join(temporary, "permit.seki");
  const permitCore = path.join(temporary, "permit.scb0");
  const permitC = path.join(temporary, "permit.c");
  fs.writeFileSync(permitSource, [
    "module grit::permit @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Candidate { epoch: U32, tier: U8 }.",
    "export record Permit { grantedEpoch: U32, grantedTier: U8 }.",
    "export variant Refusal [ Stale @ 1. LowTier @ 2. ].",
    "",
    "export kernel publish candidate: Candidate",
    "-> Decision[Permit, Refusal] arithmetic: checked",
    "bounded steps: 256 liveBits: 4096 controlDepth: 64 workspaceBits: 0",
    "rejects: Refusal::Stale, Refusal::LowTier",
    "publication: none [",
    "  require (candidate epoch) == 42 else: Refusal::Stale.",
    "  require (candidate tier) >= 3 else: Refusal::LowTier.",
    "  accept Permit { grantedTier: (candidate tier),",
    "                  grantedEpoch: (candidate epoch) }",
    "].",
    "",
  ].join("\n"));
  const permit = run([
    "build", "--core", permitCore, "--c", permitC, permitSource,
  ]);
  assert.equal(permit.status, 0, permit.stderr);
  const permitDecoded = decodeModule(fs.readFileSync(permitCore));
  checkTypedCore(permitDecoded);
  assert.deepEqual(permitDecoded.kernels[0][1].exact, [17, 121, 7, 0]);
  const permitText = fs.readFileSync(permitC, "utf8");
  assert.match(permitText,
    /uint32_t premise_tag;.*\n    seki_a0_permit_permit accepted;/u);
  // Source order was grantedTier first; canonical order is by field name, and
  // the literal is written into its destination field by field.
  assert.ok(
    permitText.indexOf("result.accepted.seki_f_grantedEpoch =") <
    permitText.indexOf("result.accepted.seki_f_grantedTier ="),
    "record fields were not written in canonical order");
  execFileSync("cc", [...strictFlags, "-c", permitC, "-o",
    path.join(temporary, "permit.o")], { stdio: "inherit" });

  // Every declared field must be supplied exactly once.
  const permitPartial = path.join(temporary, "permit-partial.seki");
  fs.writeFileSync(permitPartial, fs.readFileSync(permitSource, "utf8")
    .replace("accept Permit { grantedTier: (candidate tier),\n" +
      "                  grantedEpoch: (candidate epoch) }",
      "accept Permit { grantedTier: (candidate tier) }"));
  const partial = run(["check", permitPartial]);
  assert.equal(partial.status, 65);
  assert.match(partial.stderr, /^A0-CHECK-0021:/u);

  // One kernel exercising every form the alpha implements, kept in the repo as
  // the example a reader starts from.
  const exampleSource = "spec/language/examples/access_permit.seki";
  const exampleCore = path.join(temporary, "access_permit.scb0");
  const exampleC = path.join(temporary, "access_permit.c");
  const example = run([
    "build", "--core", exampleCore, "--c", exampleC, exampleSource,
  ]);
  assert.equal(example.status, 0, example.stderr);
  // An alias is a transparent synonym: typed-core formation rejects a
  // `Declared` reference to one, so aliases must be expanded at use sites.
  // This check is what catches an emitter that stops expanding them.
  const exampleDecoded = decodeModule(fs.readFileSync(exampleCore));
  checkTypedCore(exampleDecoded);
  const exampleText = fs.readFileSync(exampleC, "utf8");
  // C cannot copy an array, so an octet binding names the octets and an octet
  // record field is copied rather than assigned.
  assert.match(exampleText, /const uint8_t \*const seki_b0 = /u);
  assert.match(exampleText, /_octets_copy\(result\.accepted\.seki_f_account, /u);
  assert.match(exampleText, /_octets_equal\(seki_b0, /u);
  execFileSync("cc", [...strictFlags, "-c", exampleC, "-o",
    path.join(temporary, "access_permit.o")], { stdio: "inherit" });

  // Rejection precedence is structural, not an inventory the body may
  // contradict: typed-core `check_order` requires indices to increase along
  // every sequentially reachable continuation. Admission rejects a module that
  // violates it, so the compiler must too.
  const outOfOrder = path.join(temporary, "out-of-order.seki");
  fs.writeFileSync(outOfOrder, [
    "module t::prec @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "export record D { a: U8, b: U8 }.",
    "export variant R [ First @ 1. Second @ 2. ].",
    "export kernel k d: D -> Decision[Unit, R] arithmetic: checked",
    "bounded steps: 128 liveBits: 1024 controlDepth: 32 workspaceBits: 0",
    "rejects: R::First, R::Second publication: none [",
    "  require (d b) >= 1 else: R::Second.",
    "  require (d a) >= 1 else: R::First.",
    "  accept unit ].",
    "",
  ].join("\n"));
  const precedenceRun = run(["check", outOfOrder]);
  assert.equal(precedenceRun.status, 65);
  assert.match(precedenceRun.stderr, /^A0-CHECK-0023:/u);

  // Stable tag 0 is reserved so a rejection tag of 0 always means "no
  // rejection" and never names a case.
  const zeroTag = path.join(temporary, "zero-tag.seki");
  fs.writeFileSync(zeroTag,
    fs.readFileSync(outOfOrder, "utf8").replace("First @ 1.", "First @ 0."));
  const zeroed = run(["check", zeroTag]);
  assert.equal(zeroed.status, 65);
  assert.match(zeroed.stderr, /^A0-PARSE-0039:/u);

  // The decision ABI a shadow oracle compares against. Two rejections reached
  // by different inputs but identical in meaning must compare equal byte for
  // byte, which is why the whole decision is zeroed before any field is set:
  // C leaves padding unspecified.
  const abiHarness = path.join(temporary, "abi_main.c");
  fs.copyFileSync(requireC, path.join(temporary, "abi.c"));
  fs.writeFileSync(abiHarness, [
    '#include <stdint.h>',
    '#include <stdio.h>',
    '#include <string.h>',
    '#include "abi.c"',
    'int main(void) {',
    '    unsigned bad = 0U;',
    '    seki_a0_publish_candidate a, b;',
    '    seki_a0_publish_decision da, db;',
    '    a.seki_f_epoch = 1U; a.seki_f_pack = 7U; a.seki_f_tier = 9U;',
    '    b.seki_f_epoch = 2U; b.seki_f_pack = 3U; b.seki_f_tier = 1U;',
    '    da = seki_a0_publish_publish(a);',
    '    db = seki_a0_publish_publish(b);',
    '    if (memcmp(&da, &db, sizeof da) != 0) ++bad;',
    '    if (da.disposition != 2U) ++bad;',
    '    if (da.rejection_tag != 1U || da.premise_tag != 1U) ++bad;',
    '    a.seki_f_epoch = 42U; a.seki_f_pack = 3U;',
    '    da = seki_a0_publish_publish(a);',
    '    if (da.rejection_tag != 2U || da.premise_tag != 2U) ++bad;',
    '    a.seki_f_pack = 7U; a.seki_f_tier = 9U;',
    '    da = seki_a0_publish_publish(a);',
    '    if (da.disposition != 1U) ++bad;',
    '    if (da.rejection_tag != 0U || da.premise_tag != 0U) ++bad;',
    '    if (da.abi_revision != 2U) ++bad;',
    '    printf("%u\\n", bad);',
    '    return bad != 0U;',
    '}',
    '',
  ].join("\n"));
  const abiExe = path.join(temporary, "abi_main");
  execFileSync("cc", [...strictFlags, "-fsanitize=address,undefined",
    `-I${temporary}`, abiHarness, "-o", abiExe], { stdio: "inherit" });
  assert.equal(execFileSync(abiExe, { encoding: "utf8" }), "0\n");

  // A rejection can report which value failed and against what. Each
  // payload-bearing case becomes a struct and the decision holds a union of
  // them; only one is live and the decision is zeroed first, so the inactive
  // members stay byte-comparable.
  const payloadSource = path.join(temporary, "payload.seki");
  const payloadCore = path.join(temporary, "payload.scb0");
  const payloadC = path.join(temporary, "payload.c");
  fs.writeFileSync(payloadSource, [
    "module gate::payload @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export record Entry { tier: U16, region: U8 }.",
    "export variant Denial [",
    "  TierTooLow(limit: U16, actual: U16) @ 1.",
    "  WrongRegion(seen: U8) @ 2.",
    "].",
    "",
    "export kernel screen entry: Entry",
    "-> Decision[Unit, Denial] arithmetic: checked",
    "bounded steps: 256 liveBits: 4096 controlDepth: 64 workspaceBits: 0",
    "rejects: Denial::TierTooLow, Denial::WrongRegion",
    "publication: none [",
    "  require (entry tier) >= 100",
    "    else: Denial::TierTooLow(limit: 100, actual: (entry tier)).",
    "  require (entry region) == 7",
    "    else: Denial::WrongRegion(seen: (entry region)).",
    "  accept unit ].",
    "",
  ].join("\n"));
  const payload = run([
    "build", "--core", payloadCore, "--c", payloadC, payloadSource,
  ]);
  assert.equal(payload.status, 0, payload.stderr);
  const payloadDecoded = decodeModule(fs.readFileSync(payloadCore));
  checkTypedCore(payloadDecoded);
  // Payload keys are names and must be strictly increasing, so the declared
  // order `limit, actual` is emitted canonically as `actual, limit`.
  const reasonTerm = payloadDecoded.kernels[0][1].body[2].term;
  assert.equal(reasonTerm[0], 8);
  assert.deepEqual(reasonTerm[2].map(([key]) => key), ["actual", "limit"]);
  assert.deepEqual(payloadDecoded.kernels[0][1].exact, [14, 93, 6, 0]);

  const payloadHarness = path.join(temporary, "payload_main.c");
  fs.copyFileSync(payloadC, path.join(temporary, "pay.c"));
  fs.writeFileSync(payloadHarness, [
    '#include <stdint.h>',
    '#include <stdio.h>',
    '#include "pay.c"',
    'int main(void) {',
    '    unsigned bad = 0U;',
    '    for (uint32_t t = 0U; t < 300U; t += 7U)',
    '    for (unsigned r = 0U; r < 256U; r += 3U) {',
    '        seki_a0_payload_entry e; seki_a0_payload_decision d;',
    '        e.seki_f_tier = (uint16_t)t; e.seki_f_region = (uint8_t)r;',
    '        d = seki_a0_payload_screen(e);',
    '        if (d.abi_revision != 2U) { ++bad; continue; }',
    '        if (t < 100U) {',
    '            if (d.disposition != 2U || d.rejection_tag != 1U) ++bad;',
    '            else if (d.premise_tag != 1U) ++bad;',
    '            else if (d.rejection.tiertoolow.seki_f_actual != (uint16_t)t) ++bad;',
    '            else if (d.rejection.tiertoolow.seki_f_limit != 100U) ++bad;',
    '        } else if (r != 7U) {',
    '            if (d.disposition != 2U || d.rejection_tag != 2U) ++bad;',
    '            else if (d.premise_tag != 2U) ++bad;',
    '            else if (d.rejection.wrongregion.seki_f_seen != (uint8_t)r) ++bad;',
    '        } else {',
    '            if (d.disposition != 1U || d.rejection_tag != 0U) ++bad;',
    '        }',
    '    }',
    '    printf("%u\\n", bad);',
    '    return bad != 0U;',
    '}',
    '',
  ].join("\n"));
  const payloadExe = path.join(temporary, "payload_main");
  execFileSync("cc", [...strictFlags, "-fsanitize=address,undefined",
    `-I${temporary}`, payloadHarness, "-o", payloadExe], { stdio: "inherit" });
  assert.equal(execFileSync(payloadExe, { encoding: "utf8" }), "0\n");

  // Every declared payload field must be supplied exactly once.
  const payloadPartial = path.join(temporary, "payload-partial.seki");
  fs.writeFileSync(payloadPartial, fs.readFileSync(payloadSource, "utf8")
    .replace("TierTooLow(limit: 100, actual: (entry tier))",
      "TierTooLow(limit: 100)"));
  const partialPayload = run(["check", payloadPartial]);
  assert.equal(partialPayload.status, 65);
  assert.match(partialPayload.stderr, /^A0-CHECK-0024:/u);

  // Exhaustive `match` over a declared variant. A variant value is its stable
  // tag plus, where any case carries one, a union of payloads; the arms are
  // exhaustive so the switch needs no default.
  const matchSource = path.join(temporary, "match.seki");
  const matchCore = path.join(temporary, "match.scb0");
  const matchC = path.join(temporary, "match.c");
  fs.writeFileSync(matchSource, [
    "module gate::project @ 1",
    "profile: c11_bounded @ 1",
    "claims: semantic_evaluation",
    "requires: totality.",
    "",
    "export variant Operation [ Divide @ 1. FloorDiv @ 2. FloorMod @ 3. ].",
    "export record Node { op: Operation, width: U8 }.",
    "export variant Denial [ NarrowWidth @ 1. Unsupported @ 2. ].",
    "",
    "export kernel admit node: Node",
    "-> Decision[Unit, Denial] arithmetic: checked",
    "bounded steps: 512 liveBits: 4096 controlDepth: 64 workspaceBits: 0",
    "rejects: Denial::NarrowWidth, Denial::Unsupported",
    "publication: none [",
    "  require (node width) >= 32 else: Denial::NarrowWidth.",
    "  match (node op) [",
    "    Divide: [ accept unit ].",
    "    FloorDiv: [ accept unit ].",
    "    FloorMod: [ reject Denial::Unsupported ].",
    "  ]",
    "].",
    "",
  ].join("\n"));
  const matched = run(["build", "--core", matchCore, "--c", matchC, matchSource]);
  assert.equal(matched.status, 0, matched.stderr);
  const matchDecoded = decodeModule(fs.readFileSync(matchCore));
  checkTypedCore(matchDecoded);
  assert.equal(matchDecoded.kernels[0][1].body[4][0], 5);
  assert.deepEqual(matchDecoded.kernels[0][1].exact, [11, 28, 5, 0]);
  const matchText = fs.readFileSync(matchC, "utf8");
  assert.match(matchText, /typedef struct \{\n    uint32_t tag;\n\} seki_a0_project_operation;/u);
  assert.match(matchText, /switch \(seki_p_node\.seki_f_op\.tag\) \{/u);
  execFileSync("cc", [...strictFlags, "-c", matchC, "-o",
    path.join(temporary, "match.o")], { stdio: "inherit" });

  const matchHarness = path.join(temporary, "match_main.c");
  fs.copyFileSync(matchC, path.join(temporary, "mt.c"));
  fs.writeFileSync(matchHarness, [
    '#include <stdint.h>', '#include <stdio.h>', '#include "mt.c"',
    'int main(void) {',
    '    unsigned bad = 0U;',
    '    for (uint32_t op = 1U; op <= 3U; ++op)',
    '    for (unsigned w = 0U; w < 256U; ++w) {',
    '        seki_a0_project_node n; seki_a0_project_decision d;',
    '        n.seki_f_op.tag = op; n.seki_f_width = (uint8_t)w;',
    '        d = seki_a0_project_admit(n);',
    '        if (w < 32U) {',
    '            if (d.disposition != 2U || d.rejection_tag != 1U) ++bad;',
    '        } else if (op == 3U) {',
    '            if (d.disposition != 2U || d.rejection_tag != 2U) ++bad;',
    '        } else if (d.disposition != 1U) ++bad;',
    '    }',
    '    printf("%u\\n", bad);',
    '    return bad != 0U;',
    '}', '',
  ].join("\n"));
  const matchExe = path.join(temporary, "match_main");
  execFileSync("cc", [...strictFlags, "-fsanitize=address,undefined",
    `-I${temporary}`, matchHarness, "-o", matchExe], { stdio: "inherit" });
  assert.equal(execFileSync(matchExe, { encoding: "utf8" }), "0\n");

  // Arms must cover every case exactly once: a missing arm and a repeated one
  // are the same failure.
  for (const [label, edit] of [
    ["missing", (t) => t.replace("    FloorMod: [ reject Denial::Unsupported ].\n", "")],
    ["repeated", (t) => t.replace("FloorDiv: [ accept unit ].", "Divide: [ accept unit ].")],
  ]) {
    const armSource = path.join(temporary, `match-${label}.seki`);
    fs.writeFileSync(armSource, edit(fs.readFileSync(matchSource, "utf8")));
    const armRun = run(["check", armSource]);
    assert.equal(armRun.status, 65, label);
    assert.match(armRun.stderr, /^A0-CHECK-0027:/u);
  }

  // A claim the registry does not define has no tag, so the module cannot be
  // encoded at all.
  const unknownClaimSource = path.join(temporary, "unknown-claim.seki");
  fs.writeFileSync(unknownClaimSource,
    canonicalText.replace("lean_projection", "telepathy"));
  const unknownClaim = run(["check", unknownClaimSource]);
  assert.equal(unknownClaim.status, 65);
  assert.match(unknownClaim.stderr,
    /^A0-CORE-0001:.*: module is outside the alpha typed-core subset\n$/u);

  // A declared ceiling below the derived exact bound is rejected by the
  // checker before any artifact is constructed.
  const lowCeilingSource = path.join(temporary, "low-ceiling.seki");
  fs.writeFileSync(lowCeilingSource,
    canonicalText.replace("bounded steps: 32", "bounded steps: 7"));
  const lowCeiling = run(["check", lowCeilingSource]);
  assert.equal(lowCeiling.status, 65);
  assert.match(lowCeiling.stderr, /^A0-CHECK-0017:/u);

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
    /seki_p_applicant\.seki_f_age < UINT8_C\(19\)/u);

  const inspected = run(["inspect", corePath]);
  assert.equal(inspected.status, 0, inspected.stderr);
  assert.equal(inspected.stderr, "");
  assert.equal(inspected.stdout,
    "frontend=alpha-decision\n" +
    "backend=alpha-decision\n" +
    "profile=c11_bounded@1\n" +
    "first_literal=18:u8\n" +
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
    "seki_alpha_cli=verified version=0.0.0-alpha.6 commands=4 connected=3 " +
    "slice=u8-decision fields=2 rejections=2 renamed=yes overwrite=reject " +
    "operators=4 source_order=canonical table_order=name-derived " +
    "header_vectors=general nested_control=yes exhaustive=65536 " +
    "widths=u8,u16,u32,u64 declarations=n octets=constant-time " +
    "boolean=short-circuit nominals=non-substitutable require=precedence " +
    "bindings=scoped accepted=value records=constructed " +
    "aliases=expanded example=access_permit " +
    "precedence=structural tag0=reserved abi=revision-2 " +
    "payloads=typed match=exhaustive",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
