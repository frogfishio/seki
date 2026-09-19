import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-a0-lexer-"));
const executable = path.join(temporary, "test-lexer");
const flags = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wstrict-prototypes",
  "-Wmissing-prototypes", "-Wundef", "-Wformat=2", "-Isrc/alpha",
];

try {
  execFileSync("cc", [
    ...flags,
    "src/alpha/seki_lexer.c",
    "tests/alpha/test_lexer.c",
    "-o", executable,
  ], { stdio: "inherit" });
  execFileSync(executable, [], { stdio: "inherit" });
  console.log("seki_alpha_lexer=verified tokens=32 hostile=4 allocation=none");
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}

