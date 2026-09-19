import crypto from "node:crypto";
import fs from "node:fs";

const fail = message => {
  throw new Error(`E0-VS1 contract: ${message}`);
};
const expect = (condition, message) => {
  if (!condition) fail(message);
};

const contractPath = "experiments/e0-vs1/CONTRACT.json";
const contract = JSON.parse(fs.readFileSync(contractPath, "utf8"));
const source = fs.readFileSync(contract.source.path);
const digest = crypto.createHash("sha256").update(source).digest("hex");

expect(contract.schema ===
  "io.frogfish.seki/experimental-vertical-slice-contract@0",
  "unknown schema");
expect(contract.experiment === "E0-VS1", "wrong experiment identity");
expect(contract.authority === "experimental-only", "authority ceiling changed");
expect(digest === contract.source.sha256, "source digest mismatch");
expect(contract.typed_core.encoding === "SCB-0", "typed-core encoding changed");
expect(contract.typed_core.path ===
  "experiments/e0-vs1/minimum_age.scb0.hex", "typed-core path changed");
expect(contract.typed_core.length === 417, "typed-core length changed");
expect(contract.typed_core.module_sha256 ===
  "0ff1f489e9a20e7c09e60b079db62971318586129399a3c6fb119e54e36ddc9b",
  "typed-core module digest changed");

expect(contract.input.type === "Applicant", "input type changed");
expect(JSON.stringify(contract.input.fields) ===
  JSON.stringify([{ name: "age", type: "U8" }]), "input schema changed");
expect(contract.result === "Decision[Unit,Rejection]", "result type changed");
expect(contract.policy.threshold === 18, "policy threshold changed");
expect(contract.policy.below_threshold ===
  "Reject(Rejection::Underage)", "minor result changed");
expect(contract.policy.at_or_above_threshold ===
  "Accept(Unit)", "adult result changed");

const expectedExamples = new Map([
  [0, "Reject(Rejection::Underage)"],
  [17, "Reject(Rejection::Underage)"],
  [18, "Accept(Unit)"],
  [19, "Accept(Unit)"],
  [255, "Accept(Unit)"]
]);
expect(contract.boundary_examples.length === expectedExamples.size,
  "boundary example count changed");
for (const example of contract.boundary_examples) {
  expect(expectedExamples.get(example.age) === example.result,
    `unexpected boundary example for age ${example.age}`);
  expectedExamples.delete(example.age);
}
expect(expectedExamples.size === 0, "required boundary example missing");

for (const [claim, value] of Object.entries(contract.claims)) {
  expect(value === false, `${claim} must remain false during E0`);
}

console.log(`e0_vs1_contract=verified source_sha256=${digest}`);
