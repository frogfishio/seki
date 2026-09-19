import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-a0-cli-"));
const compiler = path.join(temporary, "sekic");
const source = "src/alpha/sekic.c";
const strictFlags = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wstrict-prototypes",
  "-Wmissing-prototypes", "-Wundef", "-Wformat=2",
];

function run(args) {
  return spawnSync(compiler, args, { encoding: "utf8" });
}

try {
  execFileSync("cc", [...strictFlags, source, "-o", compiler], {
    stdio: "inherit",
  });

  const version = run(["--version"]);
  assert.equal(version.status, 0);
  assert.equal(version.stderr, "");
  assert.equal(version.stdout,
    "sekic 0.0.0-alpha.1 (provisional, authority=none)\n");

  const help = run(["--help"]);
  assert.equal(help.status, 0);
  assert.match(help.stdout, /^usage:\n/u);
  assert.equal(help.stderr, "");

  for (const [name, args] of [
    ["check", ["check", "input.seki"]],
    ["build", ["build", "--core", "out.scb0", "--c", "out.c", "input.seki"]],
    ["inspect", ["inspect", "input.scb0"]],
  ]) {
    const result = run(args);
    assert.equal(result.status, 69, `${name} did not fail closed`);
    assert.equal(result.stdout, "");
    assert.match(result.stderr,
      new RegExp(`^A0-CLI-0002: ${name} is not connected`, "u"));
  }

  const bad = run(["build", "input.seki"]);
  assert.equal(bad.status, 64);
  assert.match(bad.stderr, /^usage:\n/u);

  console.log("seki_alpha_cli=verified version=0.0.0-alpha.1 commands=4 connected=0");
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}

