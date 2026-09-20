import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "seki-a0-parser-"));
const executable = path.join(temporary, "test-parser");
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
    "tests/alpha/test_parser.c",
    "-o", executable,
  ], { stdio: "inherit" });
  execFileSync(executable, [], { stdio: "inherit" });
  console.log(
    "seki_alpha_parser=verified header=general " +
    "declarations=alias,nominal,record,variant " +
    "kernel=envelope,tail-ast complete-module=yes positive=3 hostile=11 " +
    "nesting=bounded",
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
