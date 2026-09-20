import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-a0-checker-"));
const executable = path.join(temporary, "test-checker");
const flags = [
  "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror",
  "-Wconversion", "-Wsign-conversion", "-Wshadow", "-Wstrict-prototypes",
  "-Wmissing-prototypes", "-Wundef", "-Wformat=2", "-Isrc/alpha",
];

try {
  execFileSync("cc", [
    ...flags,
    "src/alpha/seki_lexer.c",
    "src/alpha/seki_parser.c",
    "src/alpha/seki_types.c",
    "src/alpha/seki_checker.c",
    "tests/alpha/test_checker.c",
    "-o", executable,
  ], { stdio: "inherit" });
  execFileSync(executable, [], { stdio: "inherit" });
  console.log(
    "seki_alpha_checker=verified slice=u8-decision positive=3 hostile=7 " +
    "exact_bounds=8,25,5,0",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
