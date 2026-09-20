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
const recordedCore = "experiments/e0-vs1/minimum_age.scb0.hex";
const recordedC = "experiments/e0-vs1/minimum_age.generated.c";
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
  assert.match(renamedCText, /result\.reason = UINT8_C\(7\)/u);
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
    '        uint8_t wt, wr;',
    '        c.seki_f_age = (uint8_t)age; c.seki_f_tier = (uint8_t)tier;',
    '        got = seki_a0_nested_screen(c);',
    '        if (tier == 0U)     { wt = 1U; wr = 9U; }',
    '        else if (age < 18U) { wt = 1U; wr = 1U; }',
    '        else if (tier > 3U) { wt = 1U; wr = 4U; }',
    '        else                { wt = 0U; wr = 0U; }',
    '        if (got.tag != wt || got.reason != wr) ++bad;',
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
    /applicant\.age < UINT8_C\(19\)/u);

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
    "boolean=short-circuit nominals=non-substitutable require=precedence",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
