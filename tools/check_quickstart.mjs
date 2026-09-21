import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/*
 * Extracts the kernel and the calling code from the quickstart and runs them.
 *
 * A quickstart that does not compile is worse than none: a reader trusts it
 * before they trust the compiler. Everything a reader is told to type is
 * therefore taken from the document itself rather than restated here.
 */

const quickstart = "docs/alpha/QUICKSTART.md";
const document = fs.readFileSync(quickstart, "utf8");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-quickstart-"));
const compiler = path.join(temporary, "sekic");
const strictFlags = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wundef", "-Wformat=2",
];

const fenced = (language) => [...document.matchAll(
  new RegExp("```" + language + "\\n([\\s\\S]*?)```", "gu"))]
  .map((block) => block[1]);

try {
  const kernels = fenced("seki");
  assert.ok(kernels.length >= 1, "the quickstart no longer shows a kernel");
  const kernel = kernels[0];

  execFileSync("cc", [...strictFlags, "-Wstrict-prototypes",
    "-Wmissing-prototypes", "-Isrc/alpha",
    "src/alpha/sekic.c", "src/alpha/seki_lexer.c", "src/alpha/seki_parser.c",
    "src/alpha/seki_types.c", "src/alpha/seki_checker.c",
    "src/alpha/seki_core.c", "src/alpha/seki_c_backend.c",
    "-o", compiler], { stdio: "inherit" });

  // Section 2: the kernel the reader is shown compiles as printed.
  const source = path.join(temporary, "gate.seki");
  fs.writeFileSync(source, kernel);
  const checked = spawnSync(compiler, ["check", source], { encoding: "utf8" });
  assert.equal(checked.status, 0,
    `the quickstart kernel does not check: ${checked.stderr}`);

  // Section 3: the invocation the reader is told to run, with its outputs.
  const built = spawnSync(compiler, [
    "build",
    "--core", path.join(temporary, "gate.scb0"),
    "--c", path.join(temporary, "gate.c"),
    "--header", path.join(temporary, "seki_a0_gate.h"),
    source,
  ], { encoding: "utf8" });
  assert.equal(built.status, 0, built.stderr);

  // Section 4: the calling code, compiled against that header. This
  // establishes that the snippet's member names and types are right, which is
  // what a reader copies. It is an illustration rather than a program, so the
  // two warnings that only fault it for being one are relaxed; everything
  // else stays strict.
  const calling = fenced("c")[0];
  assert.match(calling, /seki_a0_gate_authorise/u,
    "the quickstart no longer shows how to call a kernel");
  fs.writeFileSync(path.join(temporary, "caller.c"), [
    "#include <stdint.h>",
    "void seki_quickstart_example(void);",
    "void seki_quickstart_example(void) {",
    calling.replace(/#include "seki_a0_gate\.h"/u, ""),
    "    (void)d;",
    "}",
    "",
  ].join("\n"));
  fs.writeFileSync(path.join(temporary, "unit.c"), [
    '#include "seki_a0_gate.h"',
    '#include "caller.c"',
    "",
  ].join("\n"));
  execFileSync("cc", [...strictFlags, "-Wno-unused-variable",
    "-Wno-unused-but-set-variable", `-I${temporary}`, "-c",
    path.join(temporary, "unit.c"), "-o", path.join(temporary, "unit.o")],
    { stdio: "inherit" });
  execFileSync("cc", [...strictFlags, `-I${temporary}`, "-c",
    path.join(temporary, "gate.c"), "-o", path.join(temporary, "gate.o")],
    { stdio: "inherit" });

  // Section 2 tells a reader to read the exact cost from `inspect`, so that
  // output has to carry it.
  const inspected = spawnSync(compiler,
    ["inspect", path.join(temporary, "gate.scb0")], { encoding: "utf8" });
  assert.equal(inspected.status, 0, inspected.stderr);
  assert.match(inspected.stdout, /^exact_bounds=\d+,\d+,\d+,\d+$/mu,
    "inspect no longer reports the exact bounds the quickstart promises");
  assert.match(inspected.stdout, /^declared_ceiling=\d+,\d+,\d+,\d+$/mu);

  // Section 7: every diagnostic the table names is one the compiler can
  // actually produce, so a reader never looks up a code that cannot occur.
  const listed = [...document.matchAll(/`(A0-[A-Z]+-\d{4})`/gu)]
    .map((match) => match[1]);
  assert.ok(listed.length >= 10, "the diagnostic table shrank unexpectedly");
  const emitted = new Set();
  for (const file of fs.readdirSync("src/alpha")) {
    for (const found of fs.readFileSync(`src/alpha/${file}`, "utf8")
      .matchAll(/"(A0-[A-Z]+-\d{4})"/gu)) {
      emitted.add(found[1]);
    }
  }
  for (const code of listed) {
    assert.ok(emitted.has(code),
      `the quickstart documents ${code}, which the compiler cannot emit`);
  }

  // Section 9: the command the reader is told to ship with.
  assert.match(document, /make bundle KERNEL=/u,
    "the quickstart no longer says how to assemble a bundle");

  // Section 10 must keep saying what is not established.
  assert.match(document, /not proved to preserve/u,
    "the quickstart stopped disclosing that the C is unproved");

  console.log(
    `seki_quickstart=verified kernel=compiles caller=compiles ` +
    `diagnostics=${listed.length} all_emittable=yes`);
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
