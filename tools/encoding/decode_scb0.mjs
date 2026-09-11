// Experimental independent SCB-0 structural decoder. Not an admission checker.
import fs from "node:fs";
import { createHash } from "node:crypto";

export class AdmissionError extends Error {
  constructor(reason, path) {
    super(`${reason} ${path}`);
    this.reason = reason;
    this.path = path;
  }
}

const fail = (reason, path) => { throw new AdmissionError(reason, path); };

class Reader {
  constructor(bytes, basePath = "module") {
    this.bytes = bytes;
    this.position = 0;
    this.basePath = basePath;
  }

  u8(path) {
    if (this.position >= this.bytes.length) fail("0005", path);
    return this.bytes[this.position++];
  }

  u32(path) {
    if (this.bytes.length - this.position < 4) fail("0005", path);
    const value = this.bytes.readUInt32BE(this.position);
    this.position += 4;
    return value;
  }

  raw(length, path) {
    if (length > this.bytes.length - this.position) fail("0005", path);
    const value = this.bytes.subarray(this.position, this.position + length);
    this.position += length;
    return value;
  }

  name(path, lower = false) {
    const length = this.u32(`${path}/length`);
    if (length === 0 || length > 1024) fail("0300", path);
    const bytes = this.raw(length, path);
    for (const byte of bytes) if (byte > 0x7f) fail("0300", path);
    const value = bytes.toString("ascii");
    const grammar = lower ? /^[a-z][a-z0-9_]*$/ : /^[A-Za-z_][A-Za-z0-9_]*$/;
    if (!grammar.test(value)) fail(lower ? "0301" : "0300", path);
    return value;
  }
}

const compare = (left, right) => {
  if (typeof left === "number") return left - right;
  if (typeof left === "string") {
    return Buffer.compare(Buffer.from(left, "ascii"), Buffer.from(right, "ascii"));
  }
  if (Buffer.isBuffer(left)) return Buffer.compare(left, right);
  for (let i = 0; i < Math.min(left.length, right.length); ++i) {
    const order = compare(left[i], right[i]);
    if (order !== 0) return order;
  }
  return left.length - right.length;
};

const count = (reader, path) => {
  const value = reader.u32(`${path}/count`);
  if (value > 65536) fail("0302", path);
  return value;
};

const sequence = (reader, path, parse) => {
  const length = count(reader, path);
  const values = [];
  for (let i = 0; i < length; ++i) values.push(parse(`${path}/${i}`));
  return values;
};

const table = (reader, path, parseKey, parseValue) => {
  const length = count(reader, path);
  const entries = [];
  let previous;
  for (let i = 0; i < length; ++i) {
    const entryPath = `${path}/${i}`;
    const key = parseKey(`${entryPath}/key`);
    if (i > 0) {
      const order = compare(previous, key);
      if (order === 0) fail("0103", `${entryPath}/key`);
      if (order > 0) fail("0104", `${entryPath}/key`);
    }
    previous = key;
    entries.push([key, parseValue(`${entryPath}/value`)]);
  }
  return entries;
};

const setSequence = (reader, path, parse) => {
  const length = count(reader, path);
  const values = [];
  let previous;
  for (let i = 0; i < length; ++i) {
    const value = parse(`${path}/${i}`);
    if (i > 0) {
      const order = compare(previous, value);
      if (order === 0) fail("0105", `${path}/${i}`);
      if (order > 0) fail("0106", `${path}/${i}`);
    }
    previous = value;
    values.push(value);
  }
  return values;
};

const knownTag = (reader, path, maximum) => {
  const tag = reader.u8(path);
  if (tag > maximum) fail("0100", path);
  return tag;
};

const boolean = (reader, path) => {
  const value = reader.u8(path);
  if (value > 1) fail("0101", path);
  return value === 1;
};

const option = (reader, path, parse) => {
  const tag = reader.u8(`${path}/tag`);
  if (tag > 1) fail("0102", `${path}/tag`);
  return tag === 0 ? null : parse(`${path}/some`);
};

const moduleId = (reader, path) => {
  const parts = sequence(reader, `${path}/path`, (partPath) =>
    reader.name(partPath, true));
  if (parts.length === 0) fail("0301", `${path}/path`);
  return [parts, reader.u32(`${path}/version`)];
};

const digestId = (reader, path) => {
  const algorithm = knownTag(reader, `${path}/algorithm`, 0);
  return [algorithm, reader.raw(32, `${path}/bytes`)];
};

const typeRef = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 1);
  if (tag === 0) return [tag, reader.u32(`${path}/index`)];
  return [tag, reader.u32(`${path}/import_index`), reader.u32(`${path}/index`)];
};

const functionRef = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 1);
  if (tag === 0) return [tag, reader.u32(`${path}/index`)];
  return [tag, reader.u32(`${path}/import_index`), reader.u32(`${path}/index`)];
};

const domainRef = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 1);
  if (tag === 0) return [tag, reader.u32(`${path}/index`)];
  return [tag, reader.u32(`${path}/import_index`), reader.u32(`${path}/index`)];
};

const variantRef = (reader, path) =>
  [typeRef(reader, `${path}/owner`), reader.u32(`${path}/stable_tag`)];

const fieldOwnerRef = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 1);
  return tag === 0
    ? [tag, typeRef(reader, `${path}/record_type`)]
    : [tag, variantRef(reader, `${path}/variant_case`)];
};

const fieldRef = (reader, path) =>
  [fieldOwnerRef(reader, `${path}/owner`), reader.u32(`${path}/field_index`)];

const typeValue = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 22);
  switch (tag) {
    case 11: return [tag, reader.u32(`${path}/length`)];
    case 12: return [tag, domainRef(reader, `${path}/domain`),
      reader.u32(`${path}/length`)];
    case 13: return [tag, knownTag(reader, `${path}/algorithm`, 0),
      reader.u32(`${path}/length`)];
    case 14: return [tag, reader.u32(`${path}/bound`)];
    case 15: return [tag, typeValue(reader, `${path}/item`)];
    case 16: return [tag, typeValue(reader, `${path}/ok`),
      typeValue(reader, `${path}/error`)];
    case 17: return [tag, sequence(reader, `${path}/items`, (p) =>
      typeValue(reader, p))];
    case 18: return [tag, typeValue(reader, `${path}/item`),
      reader.u32(`${path}/length`)];
    case 19: return [tag, typeValue(reader, `${path}/item`),
      reader.u32(`${path}/capacity`)];
    case 20: return [tag, typeValue(reader, `${path}/accepted`),
      typeValue(reader, `${path}/rejection`)];
    case 21: return [tag, variantRef(reader, `${path}/case`)];
    case 22: return [tag, typeRef(reader, `${path}/reference`)];
    default: return [tag];
  }
};

const sumTypeRef = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 4);
  switch (tag) {
    case 0: return [tag, typeRef(reader, `${path}/type`)];
    case 1: return [tag, typeValue(reader, `${path}/item`)];
    case 2: return [tag, typeValue(reader, `${path}/ok`),
      typeValue(reader, `${path}/error`)];
    case 3: return [tag, typeValue(reader, `${path}/accepted`),
      typeValue(reader, `${path}/rejection`)];
    default: return [tag];
  }
};

const constructorRef = (reader, path) =>
  [sumTypeRef(reader, `${path}/owner`), reader.u32(`${path}/stable_tag`)];

const block = (reader, path) => ({
  parameters: sequence(reader, `${path}/parameters`, (p) => typeValue(reader, p)),
  result: typeValue(reader, `${path}/result`),
  body: expression(reader, `${path}/body`)
});

const expression = (reader, path) => ({
  claimedType: typeValue(reader, `${path}/claimed_type`),
  term: term(reader, `${path}/term`)
});

const term = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 35);
  const expr = (field) => expression(reader, `${path}/${field}`);
  switch (tag) {
    case 0: return [tag];
    case 1: return [tag, boolean(reader, `${path}/value`)];
    case 2: {
      const integerTag = knownTag(reader, `${path}/type`, 7);
      const widths = [1, 2, 4, 8, 1, 2, 4, 8];
      return [tag, integerTag, reader.raw(widths[integerTag], `${path}/value`)];
    }
    case 3: {
      const length = reader.u32(`${path}/length`);
      return [tag, reader.raw(length, `${path}/bytes`)];
    }
    case 4: return [tag, reader.u32(`${path}/reference`)];
    case 5: return [tag, expr("value"), expr("body")];
    case 6: return [tag, typeRef(reader, `${path}/type`),
      table(reader, `${path}/fields`, (p) => fieldRef(reader, p),
        (p) => expression(reader, p))];
    case 7: return [tag, expr("record"), fieldRef(reader, `${path}/field`)];
    case 8: return [tag, variantRef(reader, `${path}/case`),
      table(reader, `${path}/fields`, (p) => reader.name(p),
        (p) => expression(reader, p))];
    case 9: return [tag, sequence(reader, `${path}/items`, (p) => expression(reader, p))];
    case 10: return [tag, typeValue(reader, `${path}/item_type`)];
    case 11: return [tag, expr("value")];
    case 12: return [tag, typeValue(reader, `${path}/error_type`), expr("value")];
    case 13: return [tag, typeValue(reader, `${path}/ok_type`), expr("error")];
    case 14: case 15: case 17: case 18:
      return [tag, expr("left"), expr("right")];
    case 16: return [tag, expr("value")];
    case 19: return [tag, knownTag(reader, `${path}/op`, 3), expr("left"), expr("right")];
    case 20: return [tag, knownTag(reader, `${path}/policy`, 2),
      knownTag(reader, `${path}/op`, 4), expr("left"), expr("right")];
    case 21: return [tag, knownTag(reader, `${path}/policy`, 2),
      knownTag(reader, `${path}/op`, 0), expr("value")];
    case 22: return [tag, knownTag(reader, `${path}/policy`, 2),
      knownTag(reader, `${path}/direction`, 1), expr("value"), expr("count")];
    case 23: return [tag, knownTag(reader, `${path}/policy`, 2),
      knownTag(reader, `${path}/target`, 7), expr("value")];
    case 24: return [tag, expr("condition"), expr("when_true"), expr("when_false")];
    case 25: return [tag, expr("scrutinee"),
      table(reader, `${path}/arms`, (p) => constructorRef(reader, p),
        (p) => expression(reader, `${p}/body`))];
    case 26: return [tag, functionRef(reader, `${path}/function`),
      sequence(reader, `${path}/arguments`, (p) => expression(reader, p))];
    case 27: case 29: return [tag, expr("collection"), expr("index")];
    case 28: return [tag, expr("collection")];
    case 30: return [tag, expr("collection"), expr("initial"),
      block(reader, `${path}/step_block`)];
    case 31: case 32: case 33: case 34: case 35:
      return [tag, expr("collection"), block(reader, `${path}/block`)];
    default: throw new Error("unreachable term tag");
  }
};

const kernelExpression = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 5);
  switch (tag) {
    case 0: return [tag, expression(reader, `${path}/value`)];
    case 1: return [tag, expression(reader, `${path}/reason`),
      reader.u32(`${path}/precedence_index`)];
    case 2: return [tag, expression(reader, `${path}/condition`),
      expression(reader, `${path}/rejection`),
      reader.u32(`${path}/precedence_index`),
      kernelExpression(reader, `${path}/continuation`)];
    case 3: return [tag, expression(reader, `${path}/value`),
      kernelExpression(reader, `${path}/body`)];
    case 4: return [tag, expression(reader, `${path}/condition`),
      kernelExpression(reader, `${path}/when_true`),
      kernelExpression(reader, `${path}/when_false`)];
    case 5: return [tag, expression(reader, `${path}/scrutinee`),
      table(reader, `${path}/arms`, (p) => constructorRef(reader, p),
        (p) => kernelExpression(reader, `${p}/body`))];
    default: throw new Error("unreachable kernel tag");
  }
};

const resourceBounds = (reader, path) => [
  reader.u32(`${path}/logical_steps`),
  reader.u32(`${path}/maximum_live_value_bits`),
  reader.u32(`${path}/maximum_control_depth`),
  reader.u32(`${path}/maximum_workspace_bits`)
];

const functionKey = (reader, path) => [reader.name(`${path}/base`),
  sequence(reader, `${path}/labels`, (p) => reader.name(p))];

const functionBody = (reader, path) => ({
  parameters: sequence(reader, `${path}/parameter_types`, (p) => typeValue(reader, p)),
  result: typeValue(reader, `${path}/result`),
  body: expression(reader, `${path}/body`),
  declared: resourceBounds(reader, `${path}/declared_ceiling`),
  exact: resourceBounds(reader, `${path}/exact_derived_bounds`)
});

const kernelBody = (reader, path) => ({
  parameters: sequence(reader, `${path}/parameter_types`, (p) => typeValue(reader, p)),
  result: typeValue(reader, `${path}/result`),
  rejectionOrder: sequence(reader, `${path}/rejection_order`, (p) => variantRef(reader, p)),
  body: kernelExpression(reader, `${path}/body`),
  declared: resourceBounds(reader, `${path}/declared_ceiling`),
  exact: resourceBounds(reader, `${path}/exact_derived_bounds`),
  publicationEligible: boolean(reader, `${path}/publication_eligible`)
});

const localTypeDependencies = (type, result) => {
  if (type[0] === 22 && type[1][0] === 0) result.add(type[1][1]);
  for (const value of type.slice(1)) {
    if (Array.isArray(value) && typeof value[0] === "number") {
      localTypeDependencies(value, result);
    } else if (Array.isArray(value)) {
      for (const item of value) if (Array.isArray(item)) localTypeDependencies(item, result);
    }
  }
};

const typeDeclaration = (reader, path) => {
  const tag = knownTag(reader, `${path}/tag`, 3);
  const types = [];
  let body;
  if (tag === 0 || tag === 1) {
    body = typeValue(reader, `${path}/${tag === 0 ? "target" : "representation"}`);
    types.push(body);
  }
  if (tag === 2) {
    body = table(reader, `${path}/fields`, (p) => reader.name(p),
      (p) => typeValue(reader, `${p}/type`));
    types.push(...body.map(([, type]) => type));
  }
  if (tag === 3) {
    body = table(reader, `${path}/cases`, (p) => reader.u32(p), (p) => ({
      name: reader.name(`${p}/name`),
      payload: option(reader, `${p}/payload`, (payloadPath) =>
        table(reader, `${payloadPath}/fields`, (q) => reader.name(q),
          (q) => typeValue(reader, `${q}/type`)))
    }));
    for (const [, variantCase] of body) {
      for (const [, type] of variantCase.payload ?? []) types.push(type);
    }
  }
  const dependencies = new Set();
  for (const type of types) localTypeDependencies(type, dependencies);
  return { tag, dependencies, types, body };
};

const validateTypeOrder = (declarations, order) => {
  if (order.length !== declarations.length) fail("0d01", "module/derivations/type_order");
  const used = new Set();
  for (let position = 0; position < order.length; ++position) {
    let expected = null;
    for (let candidate = 0; candidate < declarations.length; ++candidate) {
      if (used.has(candidate)) continue;
      const ready = [...declarations[candidate].dependencies].every((dep) => used.has(dep));
      if (ready) { expected = candidate; break; }
    }
    if (expected === null) fail("0602", "module/types");
    if (order[position] !== expected) fail("0d02",
      `module/derivations/type_order/${position}`);
    used.add(expected);
  }
};

const collectLocalCalls = (value, result) => {
  if (Buffer.isBuffer(value) || value === null || value === undefined) return;
  if (Array.isArray(value)) {
    if (value[0] === 26 && Array.isArray(value[1]) && value[1][0] === 0) {
      result.add(value[1][1]);
    }
    for (const item of value) collectLocalCalls(item, result);
    return;
  }
  if (typeof value === "object") {
    for (const item of Object.values(value)) collectLocalCalls(item, result);
  }
};

const validateFunctionOrder = (functions, order) => {
  if (order.length !== functions.length) fail("0d03",
    "module/derivations/function_order");
  const dependencies = functions.map(([, body]) => {
    const found = new Set();
    collectLocalCalls(body.body.term, found);
    return found;
  });
  const used = new Set();
  for (let position = 0; position < order.length; ++position) {
    let expected = null;
    for (let candidate = 0; candidate < functions.length; ++candidate) {
      if (used.has(candidate)) continue;
      if ([...dependencies[candidate]].every((dep) => used.has(dep))) {
        expected = candidate;
        break;
      }
    }
    if (expected === null) fail("0900", "module/functions");
    if (order[position] !== expected) fail("0d04",
      `module/derivations/function_order/${position}`);
    used.add(expected);
  }
};

const parseModulePayload = (reader) => {
  const schema = reader.u32("module/schema_version");
  if (schema !== 0) fail("0200", "module/schema_version");
  const identity = moduleId(reader, "module/identity");
  const profile = [reader.name("module/profile/name", true),
    reader.u32("module/profile/version")];
  const imports = table(reader, "module/imports", (p) => moduleId(reader, p),
    (p) => digestId(reader, `${p}/digest`));
  const domains = table(reader, "module/domains", (p) => reader.name(p), () => null);
  const typeEntries = table(reader, "module/types", (p) => reader.name(p),
    (p) => typeDeclaration(reader, p));
  const functions = table(reader, "module/functions", (p) => functionKey(reader, p),
    (p) => functionBody(reader, p));
  const kernels = table(reader, "module/kernels", (p) => functionKey(reader, p),
    (p) => kernelBody(reader, p));
  const exports = {
    domains: setSequence(reader, "module/exports/domains", (p) => reader.u32(p)),
    types: setSequence(reader, "module/exports/types", (p) => reader.u32(p)),
    functions: setSequence(reader, "module/exports/functions", (p) => reader.u32(p)),
    kernels: setSequence(reader, "module/exports/kernels", (p) => reader.u32(p))
  };
  const theorems = setSequence(reader, "module/required_theorems",
    (p) => knownTag(reader, p, 6));
  const claims = setSequence(reader, "module/claim_ceiling",
    (p) => knownTag(reader, p, 7));
  const moduleBounds = [
    reader.u32("module/bounds/maximum_input_bytes"),
    reader.u32("module/bounds/maximum_typed_core_bytes"),
    reader.u32("module/bounds/maximum_imports"),
    reader.u32("module/bounds/maximum_declarations"),
    reader.u32("module/bounds/maximum_expression_nodes"),
    reader.u32("module/bounds/maximum_nesting"),
    reader.u32("module/bounds/maximum_call_depth"),
    resourceBounds(reader, "module/bounds/maximum_resource_bounds")
  ];
  const derivationSchema = reader.u32("module/derivations/schema_version");
  if (derivationSchema !== 0) fail("0d00", "module/derivations/schema_version");
  const typeOrder = sequence(reader, "module/derivations/type_order", (p) => reader.u32(p));
  const functionOrder = sequence(reader, "module/derivations/function_order", (p) => reader.u32(p));
  validateTypeOrder(typeEntries.map(([, value]) => value), typeOrder);
  validateFunctionOrder(functions, functionOrder);
  for (const index of exports.domains) if (index >= domains.length) {
    fail("0503", "module/exports/domains");
  }
  for (const index of exports.types) if (index >= typeEntries.length) {
    fail("0503", "module/exports/types");
  }
  for (const index of exports.functions) if (index >= functions.length) {
    fail("0503", "module/exports/functions");
  }
  for (const index of exports.kernels) if (index >= kernels.length) {
    fail("0503", "module/exports/kernels");
  }
  return { schema, identity, profile, imports, domains, types: typeEntries,
    functions, kernels, exports, theorems, claims, moduleBounds,
    derivations: { typeOrder, functionOrder } };
};

export const decodeModule = (bytes) => {
  if (bytes.length > 16777216) fail("0000", "envelope");
  if (bytes.length < 13) fail("0005", "envelope");
  if (!bytes.subarray(0, 4).equals(Buffer.from("SEKI", "ascii"))) {
    fail("0001", "envelope/magic");
  }
  const envelope = new Reader(bytes, "envelope");
  envelope.position = 4;
  const version = envelope.u32("envelope/version");
  if (version !== 0) fail("0002", "envelope/version");
  const kind = envelope.u8("envelope/kind");
  if (kind !== 0) fail("0003", "envelope/kind");
  const payloadLength = envelope.u32("envelope/payload_length");
  const end = 13 + payloadLength;
  if (end > bytes.length) fail("0005", "envelope/payload");
  if (end < bytes.length) fail("0006", "envelope/trailing");
  const payload = new Reader(bytes.subarray(13, end));
  const module = parseModulePayload(payload);
  if (payload.position !== payload.bytes.length) fail("0004", "module/trailing");
  const hash = createHash("sha256");
  hash.update("io.frogfish.seki/module/scb0/sha256", "ascii");
  hash.update(Buffer.from([0]));
  hash.update(bytes);
  module.canonicalBytes = bytes;
  module.digest = hash.digest();
  return module;
};

const identityKey = (identity) => `${identity[0].join("::")}@${identity[1]}`;

const resolveImported = (module, reference, exportKind, byIdentity, path) => {
  if (reference[0] === 0) return;
  const importEntry = module.imports[reference[1]];
  if (!importEntry) fail("0406", path);
  const dependency = byIdentity.get(identityKey(importEntry[0]));
  if (!dependency) fail("0401", path);
  const exports = dependency.exports[exportKind];
  if (!exports.includes(reference[2])) fail("0408", path);
};

const validateTypeImports = (type, module, byIdentity, path) => {
  switch (type[0]) {
    case 12:
      resolveImported(module, type[1], "domains", byIdentity, `${path}/domain`);
      break;
    case 15: case 18: case 19:
      validateTypeImports(type[1], module, byIdentity, `${path}/item`);
      break;
    case 16: case 20:
      validateTypeImports(type[1], module, byIdentity, `${path}/left`);
      validateTypeImports(type[2], module, byIdentity, `${path}/right`);
      break;
    case 17:
      type[1].forEach((item, index) => validateTypeImports(item, module, byIdentity,
        `${path}/items/${index}`));
      break;
    case 21:
      resolveImported(module, type[1][0], "types", byIdentity, `${path}/case/owner`);
      break;
    case 22:
      resolveImported(module, type[1], "types", byIdentity, `${path}/reference`);
      break;
  }
};

const validateExpressionImports = (expression, module, byIdentity, path) => {
  validateTypeImports(expression.claimedType, module, byIdentity, `${path}/claimed_type`);
  const walk = (value, valuePath) => {
    if (Buffer.isBuffer(value) || value === null || value === undefined) return;
    if (Array.isArray(value)) {
      if (value[0] === 26 && Array.isArray(value[1])) {
        resolveImported(module, value[1], "functions", byIdentity,
          `${valuePath}/function`);
      }
      value.forEach((item, index) => walk(item, `${valuePath}/${index}`));
      return;
    }
    if (typeof value === "object") {
      if (Object.hasOwn(value, "claimedType")) {
        validateExpressionImports(value, module, byIdentity, valuePath);
        return;
      }
      if (Object.hasOwn(value, "parameters") && Object.hasOwn(value, "body")) {
        value.parameters.forEach((type, index) => validateTypeImports(type, module,
          byIdentity, `${valuePath}/parameters/${index}`));
        validateTypeImports(value.result, module, byIdentity, `${valuePath}/result`);
      }
      for (const [key, item] of Object.entries(value)) walk(item, `${valuePath}/${key}`);
    }
  };
  walk(expression.term, `${path}/term`);
};

const validateModuleImportedReferences = (module, byIdentity) => {
  module.types.forEach(([, declaration], declarationIndex) => {
    declaration.types.forEach((type, typeIndex) => validateTypeImports(type, module,
      byIdentity, `module/types/${declarationIndex}/types/${typeIndex}`));
  });
  module.functions.forEach(([, body], functionIndex) => {
    body.parameters.forEach((type, index) => validateTypeImports(type, module,
      byIdentity, `module/functions/${functionIndex}/parameters/${index}`));
    validateTypeImports(body.result, module, byIdentity,
      `module/functions/${functionIndex}/result`);
    validateExpressionImports(body.body, module, byIdentity,
      `module/functions/${functionIndex}/body`);
  });
  module.kernels.forEach(([, body], kernelIndex) => {
    body.parameters.forEach((type, index) => validateTypeImports(type, module,
      byIdentity, `module/kernels/${kernelIndex}/parameters/${index}`));
    validateTypeImports(body.result, module, byIdentity,
      `module/kernels/${kernelIndex}/result`);
    const walkKernel = (value, path) => {
      if (value && typeof value === "object" && !Buffer.isBuffer(value)) {
        if (Object.hasOwn(value, "claimedType")) {
          validateExpressionImports(value, module, byIdentity, path);
        } else if (Array.isArray(value)) {
          value.forEach((item, index) => walkKernel(item, `${path}/${index}`));
        }
      }
    };
    walkKernel(body.body, `module/kernels/${kernelIndex}/body`);
  });
};

export const decodeBundle = (bytes) => {
  if (bytes.length > 16777216) fail("0000", "envelope");
  if (bytes.length < 13) fail("0005", "envelope");
  if (!bytes.subarray(0, 4).equals(Buffer.from("SEKI", "ascii"))) {
    fail("0001", "envelope/magic");
  }
  const envelope = new Reader(bytes);
  envelope.position = 4;
  if (envelope.u32("envelope/version") !== 0) fail("0002", "envelope/version");
  if (envelope.u8("envelope/kind") !== 1) fail("0003", "envelope/kind");
  const payloadLength = envelope.u32("envelope/payload_length");
  const end = 13 + payloadLength;
  if (end > bytes.length) fail("0005", "envelope/payload");
  if (end < bytes.length) fail("0006", "envelope/trailing");

  const reader = new Reader(bytes.subarray(13));
  const root = moduleId(reader, "bundle/root");
  const moduleCount = reader.u32("bundle/modules/count");
  if (moduleCount > 32) fail("0007", "bundle/modules/count");
  const modules = [];
  let previousIdentity;
  for (let index = 0; index < moduleCount; ++index) {
    const path = `bundle/modules/${index}`;
    if (reader.bytes.length - reader.position < 13) fail("0005", path);
    const start = reader.position;
    const nestedLength = reader.bytes.readUInt32BE(start + 9);
    const extent = 13 + nestedLength;
    if (extent > reader.bytes.length - start) fail("0005", path);
    const module = decodeModule(reader.bytes.subarray(start, start + extent));
    reader.position += extent;
    if (previousIdentity !== undefined) {
      const order = compare(previousIdentity, module.identity);
      if (order === 0) fail("0400", `${path}/identity`);
      if (order > 0) fail("0104", `${path}/identity`);
    }
    previousIdentity = module.identity;
    modules.push(module);
  }
  if (reader.position !== reader.bytes.length) fail("0004", "bundle/trailing");

  const byIdentity = new Map(modules.map((module) =>
    [identityKey(module.identity), module]));
  const rootModule = byIdentity.get(identityKey(root));
  if (!rootModule) fail("0204", "bundle/root");

  for (const module of modules) {
    for (const [importId, importDigest] of module.imports) {
      const dependency = byIdentity.get(identityKey(importId));
      if (!dependency) fail("0401", `${identityKey(module.identity)}/imports`);
      if (compare(module.profile, dependency.profile) !== 0) {
        fail("0403", `${identityKey(module.identity)}/imports`);
      }
    }
  }

  const visiting = new Set();
  const reachable = new Set();
  const visit = (module) => {
    const key = identityKey(module.identity);
    if (visiting.has(key)) fail("0404", `${key}/imports`);
    if (reachable.has(key)) return;
    visiting.add(key);
    for (const [importId] of module.imports) visit(byIdentity.get(identityKey(importId)));
    visiting.delete(key);
    reachable.add(key);
  };
  visit(rootModule);
  if (reachable.size !== modules.length) fail("0402", "bundle/modules");
  for (const module of modules) {
    for (const [importId, importDigest] of module.imports) {
      const dependency = byIdentity.get(identityKey(importId));
      if (!dependency.digest.equals(importDigest[1])) {
        fail("0405", `${identityKey(module.identity)}/imports`);
      }
    }
  }
  for (const module of modules) validateModuleImportedReferences(module, byIdentity);
  return { root, modules, rootModule };
};

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  try {
    const input = fs.readFileSync(process.argv[2]);
    const isBundle = input.length >= 9 && input[8] === 1;
    const decoded = isBundle ? decodeBundle(input) : decodeModule(input);
    const module = isBundle ? decoded.rootModule : decoded;
    console.log(JSON.stringify({
      result: isBundle ? "decoded-bundle" : "decoded",
      identity: module.identity,
      modules: isBundle ? decoded.modules.length : undefined,
      domains: module.domains.length,
      types: module.types.length,
      functions: module.functions.length,
      kernels: module.kernels.length
    }));
  } catch (error) {
    if (error instanceof AdmissionError) {
      console.log(JSON.stringify({ result: "rejected", reason: error.reason,
        path: error.path }));
      process.exitCode = 1;
    } else throw error;
  }
}
