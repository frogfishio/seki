import fs from "node:fs";

const project = JSON.parse(fs.readFileSync("PROJECT_STATUS.json", "utf8"));
const clean = JSON.parse(fs.readFileSync("toolchains/CLEAN_ROOM.json", "utf8"));
const exception = fs.readFileSync("SEKI_OUTPUT_EXCEPTION", "utf8");
const foundations = fs.readFileSync("toolchains/FOUNDATIONS.toml", "utf8");

const expect = (condition, message) => {
  if (!condition) throw new Error(`Seki bootstrap closure: ${message}`);
};

expect(project.bootstrap_status === "complete", "bootstrap is not complete");
expect(project.bootstrap_clean_room_verified === true,
  "bootstrap clean-room run is not recorded");
expect(project.current_stage === "A0", "completed bootstrap did not enter A0");
expect(project.runtime_exception === "Seki-Generated-Output-Exception-1.0",
  "runtime exception identity drift");
expect(project.clean_room_environment === "toolchains/CLEAN_ROOM.json",
  "clean-room lock path drift");
expect(clean.schema === "io.frogfish.seki/clean-room@1",
  "unknown clean-room schema");
expect(clean.status === "pinned-bootstrap-environment",
  "clean-room environment is not pinned");
expect(clean.platform === "linux/amd64", "qualification platform drift");
expect(clean.image.endsWith(`@sha256:${clean.image_manifest_sha256}`),
  "container image is not bound to its platform manifest");
expect(clean.commands.join(",") === "make check", "clean-room command drift");
expect(clean.formal_foundations_included === false,
  "bootstrap CI must not imply formal-foundation installation");
expect(clean.qualification_authority === false,
  "bootstrap CI granted qualification authority");
expect(clean.last_local_execution?.result === "pass" &&
  clean.last_local_execution?.command === "make check",
  "successful pinned-environment execution is not recorded");
expect(clean.last_local_execution?.source_state === "mounted-working-tree",
  "local execution source-state disclosure drift");
// The pinned-environment identities remain recorded, but no hosted workflow
// re-checks them: the portfolio is run locally. `last_local_execution` below
// is therefore the only execution evidence this repository carries.
expect(exception.startsWith("Seki Generated Output Exception, version 1.0\n"),
  "output exception title/version drift");
expect(exception.includes("additional permission under section 7"),
  "output exception is not expressed as a GPLv3 additional permission");
expect(exception.includes("terms of your choice"),
  "output exception lost customer-controlled licensing permission");
for (const identity of [
  'version = "4.30.0"',
  'commit = "d024af099ca4bf2c86f649261ebf59565dc8c622"',
  'version = "9.2.0"',
  'commit = "adfbf1855c348766beb4b790dcc8ebc02f908f63"',
  'version = "3.18"',
  'commit = "14d616046360a0b2611ebdfc2f98368af402e1f7"'
]) expect(foundations.includes(identity), `foundation summary missing ${identity}`);

console.log(
  `seki_bootstrap=complete stage=${project.current_stage} ` +
  `clean_room=${clean.platform} exception=1.0 authority=false`
);
