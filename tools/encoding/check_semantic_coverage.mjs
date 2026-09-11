import fs from "node:fs";

const coverage = JSON.parse(fs.readFileSync(
  "spec/typed-core/SEMANTIC_COVERAGE_V0.json", "utf8"));
if (coverage.schema !== "io.frogfish.seki/semantic-coverage@0") {
  throw new Error("semantic coverage schema mismatch");
}
const expected = {
  types: ["Unit", "Bool", "U8", "U16", "U32", "U64", "I8", "I16", "I32", "I64",
    "ArithmeticError", "Bytes", "Identity", "Digest", "Index", "Option", "Result",
    "Tuple", "Array", "Decision", "VariantPayload", "Declared"],
  declarations: ["Alias", "Nominal", "Record", "Variant"],
  terms: ["UnitLit", "BoolLit", "IntLit", "BytesLit", "Local", "Let", "Record",
    "Project", "Variant", "Tuple", "OptionNone", "OptionSome", "ResultOk",
    "ResultError", "Equal", "NotEqual", "Not", "AndThen", "OrElse", "Compare",
    "IntBinary", "IntUnary", "IntShift", "IntConvert", "If", "Match", "Call",
    "ArrayGet", "ArrayFold", "ArrayFindUnique", "ArrayAll", "ArrayAny", "ArrayMap"],
  kernel_terms: ["Accept", "Reject", "Require", "Let", "If", "Match"]
};
let covered = 0; let gaps = 0;
for (const [family, names] of Object.entries(expected)) {
  const entries = coverage[family];
  if (!Array.isArray(entries) || entries.length !== names.length) {
    throw new Error(`${family}: incomplete tag ledger`);
  }
  entries.forEach(([tag, name, fixture], index) => {
    if (tag !== index || name !== names[index]) throw new Error(`${family}/${index}: tag drift`);
    if (fixture !== null && (typeof fixture !== "string" || fixture.length === 0)) {
      throw new Error(`${family}/${index}: invalid fixture`);
    }
    fixture === null ? ++gaps : ++covered;
  });
}
if (!Array.isArray(coverage.rule_gaps)) throw new Error("semantic rule-gap ledger absent");
console.log(`semantic_coverage=verified tagged_forms=${covered + gaps} positive=${covered} positive_gaps=${gaps} rule_gaps=${coverage.rule_gaps.length}`);
