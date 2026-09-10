import fs from "node:fs";

const record = JSON.parse(fs.readFileSync(
  "docs/architecture/SEKI_V0_3_KIKU_F0_ACCEPTANCE.json", "utf8"));
const report = fs.readFileSync(
  "docs/architecture/SEKI_V0_3_KIKU_F0_ACCEPTANCE.md", "utf8");
const request = fs.readFileSync(
  "docs/architecture/SEKI_F0_INDEPENDENT_CONSUMER_REVIEW_REQUEST.md", "utf8");
const expect = (condition, message) => {
  if (!condition) throw new Error(`Seki-F0-Kiku: ${message}`);
};

expect(record.schema === "io.frogfish.seki/f0-consumer-acceptance@1" &&
  record.language_identity === "io.frogfish.seki/language@0" &&
  record.revision === "0.3", "acceptance identity drift");
expect(record.decision === "accepted_seki_v0_3_for_f0" &&
  record.accepted_gnosis_commit === "65692f383d31b2d50d694f68133be578528b0710",
"accepted decision or source identity drift");
expect(record.accepted_paths.length === 8, "accepted path inventory drift");
expect(record.claims_granted.length === 0 && record.claims_withheld.length === 6,
  "claim ceiling weakened");
expect(record.kiku_f0_review_closed === true &&
  record.independent_consumer_f0_review === "pending" &&
  record.global_f0_closed === false,
"Kiku and global F0 state conflated");
for (const phrase of [
  "accepted_seki_v0_3_for_f0",
  "Kiku's F0 review only",
  "independent_consumer_f0_review=pending",
  "global_f0=open"
]) expect(report.includes(phrase), `acceptance report omits ${phrase}`);
for (const phrase of [
  "materially different",
  "accepted_seki_v0_3_independent_consumer_for_f0",
  "This is a charter review only",
  "F1 implementation may then begin"
]) expect(request.includes(phrase), `independent review request omits ${phrase}`);

console.log("seki_f0_kiku=accepted independent_consumer=pending global_f0=open authority=none");
