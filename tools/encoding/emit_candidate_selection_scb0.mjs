// Experimental SCB-0 candidate-selection fixture emitter. Not a compiler.
import { createHash } from "node:crypto";

let chunks = [];
const u8 = (value) => chunks.push(Buffer.from([value]));
const u32 = (value) => {
  const bytes = Buffer.alloc(4);
  bytes.writeUInt32BE(value);
  chunks.push(bytes);
};
const raw = (value) => chunks.push(Buffer.from(value));
const name = (value) => {
  const bytes = Buffer.from(value, "ascii");
  u32(bytes.length);
  raw(bytes);
};
const sequence = (items, emit = (item) => item()) => {
  u32(items.length);
  for (const item of items) emit(item);
};
const none = () => u8(0);

const typeRef = (index) => { u8(0); u32(index); };
const domainRef = (index) => { u8(0); u32(index); };
const variantRef = (owner, tag) => { typeRef(owner); u32(tag); };
const fieldRef = (owner, index) => { u8(0); typeRef(owner); u32(index); };

const typeLeaf = (tag) => () => u8(tag);
const unitType = typeLeaf(0);
const boolType = typeLeaf(1);
const u64Type = typeLeaf(5);
const declaredType = (index) => () => { u8(21); typeRef(index); };
const identityType = (domain, length) => () => {
  u8(12); domainRef(domain); u32(length);
};
const optionType = (item) => () => { u8(15); item(); };
const resultType = (ok, error) => () => { u8(16); ok(); error(); };
const arrayType = (item, length) => () => {
  u8(18); item(); u32(length);
};
const decisionType = (accepted, rejection) => () => {
  u8(19); accepted(); rejection();
};

const candidateType = declaredType(0);
const candidateIdType = declaredType(1);
const epochType = declaredType(2);
const inputType = declaredType(3);
const rejectionType = declaredType(4);
const candidateArrayType = arrayType(candidateType, 32);
const optionCandidateType = optionType(candidateType);
const selectionType = resultType(optionCandidateType, unitType);
const kernelResultType = decisionType(candidateType, rejectionType);

const expr = (type, term) => { type(); term(); };
const local = (type, index) => () => expr(type, () => { u8(4); u32(index); });
const project = (type, record, owner, index) => () => expr(type, () => {
  u8(7); record(); fieldRef(owner, index);
});
const equal = (left, right) => () => expr(boolType, () => {
  u8(14); left(); right();
});
const variant = (tag) => () => expr(rejectionType, () => {
  u8(8); variantRef(4, tag); sequence([]);
});

const predicateBody = equal(
  project(candidateIdType, local(candidateType, 0), 0, 2),
  project(candidateIdType, local(inputType, 1), 3, 2)
);

const selectionExpr = () => expr(selectionType, () => {
  u8(29);
  project(candidateArrayType, local(inputType, 0), 3, 0)();
  sequence([candidateType], (type) => type());
  boolType();
  predicateBody();
});

const constructorResult = (tag) => {
  u8(2); optionCandidateType(); unitType(); u32(tag);
};
const constructorOption = (tag) => {
  u8(1); candidateType(); u32(tag);
};

const kernelReject = (tag, precedence) => {
  u8(1); variant(tag)(); u32(precedence);
};
const kernelAcceptCandidate = () => {
  u8(0); local(candidateType, 0)();
};

const someArm = () => {
  u8(2); // KernelRequire: stale
  equal(
    project(epochType, local(candidateType, 0), 0, 1),
    project(epochType, local(inputType, 3), 3, 1)
  )();
  variant(3)();
  u32(2);
  u8(2); // KernelRequire: disabled
  project(boolType, local(candidateType, 0), 0, 0)();
  variant(4)();
  u32(3);
  kernelAcceptCandidate();
};

const optionMatch = () => {
  u8(5);
  local(optionCandidateType, 0)();
  u32(2);
  constructorOption(0); kernelReject(1, 0);
  constructorOption(1); someArm();
};

const resultMatch = () => {
  u8(5);
  local(selectionType, 0)();
  u32(2);
  constructorResult(0); optionMatch();
  constructorResult(1); kernelReject(2, 1);
};

const kernelExpression = () => {
  u8(3); // KernelLet
  selectionExpr();
  resultMatch();
};

const field = (fieldName, fieldType) => {
  name(fieldName); fieldType();
};
const recordBody = (fields) => {
  u8(2); sequence(fields, ([fieldName, fieldType]) => field(fieldName, fieldType));
};
const nominalBody = (representation) => { u8(1); representation(); };
const variantCase = (tag, caseName) => {
  u32(tag); name(caseName); none();
};
const variantBody = (cases) => {
  u8(3); sequence(cases, ([tag, caseName]) => variantCase(tag, caseName));
};

const resourceBounds = (steps, live, depth, workspace) => {
  u32(steps); u32(live); u32(depth); u32(workspace);
};

const kernelBody = () => {
  sequence([inputType], (type) => type());
  kernelResultType();
  sequence([1, 2, 3, 4], (tag) => variantRef(4, tag));
  kernelExpression();
  resourceBounds(2048, 32768, 64, 4096);
  resourceBounds(212, 19361, 8, 201);
  u8(0);
};

const functionKey = (base, labels) => {
  name(base); sequence(labels, (label) => name(label));
};

const moduleBounds = () => {
  u32(1048576);  // maximum_typed_core_bytes
  u32(32);       // maximum_imports
  u32(4096);     // maximum_declarations
  u32(65536);    // maximum_expression_nodes
  u32(256);      // maximum_nesting
  u32(32);       // maximum_call_depth
  resourceBounds(16777216, 8388608, 256, 8388608);
};

const modulePayload = () => {
  chunks = [];
  u32(0); // typed-core schema version; LanguageId occupies zero octets

  sequence(["seki", "examples", "candidate_selection"], (part) => name(part));
  u32(1);
  name("c11_bounded"); u32(1);

  sequence([]); // imports
  sequence([["CandidateIdentity"]], ([key]) => { name(key); });
  sequence([
    ["Candidate", () => recordBody([
      ["enabled", boolType], ["epoch", epochType], ["id", candidateIdType]
    ])],
    ["CandidateId", () => nominalBody(identityType(0, 16))],
    ["Epoch", () => nominalBody(u64Type)],
    ["Input", () => recordBody([
      ["candidates", candidateArrayType], ["currentEpoch", epochType],
      ["wanted", candidateIdType]
    ])],
    ["Rejection", () => variantBody([
      [1, "Missing"], [2, "Duplicate"], [3, "Stale"], [4, "Disabled"]
    ])]
  ], ([key, body]) => { name(key); body(); });
  sequence([]); // functions
  sequence([["select", ["input"]]], ([base, labels]) => {
    functionKey(base, labels); kernelBody();
  });

  sequence([0], u32);             // exported domains
  sequence([0, 1, 2, 3, 4], u32);// exported types
  sequence([]);                   // exported functions
  sequence([0], u32);             // exported kernels
  sequence([0, 1, 2, 3, 4], u8); // theorem requirements
  sequence([0], u8);              // claim ceiling
  moduleBounds();
  u32(0);                         // derivation schema version
  sequence([1, 2, 0, 3, 4], u32);// type dependency order
  sequence([]);                   // function dependency order
  return Buffer.concat(chunks);
};

const payload = modulePayload();
chunks = [];
raw("SEKI"); u32(0); u8(0); u32(payload.length); raw(payload);
const moduleBytes = Buffer.concat(chunks);

if (process.argv[2] === "--hex") {
  process.stdout.write(`${moduleBytes.toString("hex")}\n`);
} else if (process.argv[2] === "--digest") {
  const hash = createHash("sha256");
  hash.update("io.frogfish.seki/module/scb0/sha256", "ascii");
  hash.update(Buffer.from([0]));
  hash.update(moduleBytes);
  process.stdout.write(`${hash.digest("hex")}\n`);
} else if (process.argv[2] === "--length") {
  process.stdout.write(`${moduleBytes.length}\n`);
} else {
  process.stdout.write(moduleBytes);
}
