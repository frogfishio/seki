import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import { AdmissionError, decodeBundle } from "./decode_scb0.mjs";

const emit = (mode) => execFileSync(process.execPath,
  ["tools/encoding/emit_import_bundle_scb0.mjs", mode]);
const manifest = JSON.parse(fs.readFileSync(
  "spec/encoding/vectors/import-bundle-v0.json", "utf8"));
const base = emit("--base");
const consumer = emit("--consumer");
const bundle = emit("--bundle");

const moduleDigest = (bytes) => createHash("sha256")
  .update(manifest.digest_domain_ascii, "ascii")
  .update(Buffer.from(manifest.digest_domain_terminator_hex, "hex"))
  .update(bytes).digest();
const rawDigest = (bytes) => createHash("sha256").update(bytes).digest("hex");

const equal = (actual, expected, label) => {
  if (actual !== expected) throw new Error(`${label}: ${actual} != ${expected}`);
};
equal(base.length, manifest.base_length, "base length");
equal(moduleDigest(base).toString("hex"), manifest.base_module_sha256, "base digest");
equal(consumer.length, manifest.consumer_length, "consumer length");
equal(moduleDigest(consumer).toString("hex"), manifest.consumer_module_sha256,
  "consumer digest");
equal(bundle.length, manifest.bundle_length, "bundle length");
equal(rawDigest(bundle), manifest.bundle_transport_sha256, "bundle transport digest");

const decoded = decodeBundle(bundle);
equal(decoded.modules.length, 2, "decoded module count");
equal(decoded.rootModule.functions.length, 2, "consumer function count");
console.log("bundle_positive=import-bundle-v0 modules=2 functions=2");

const u32 = (value) => {
  const bytes = Buffer.alloc(4); bytes.writeUInt32BE(value); return bytes;
};
const envelope = (kind, payload) => Buffer.concat([
  Buffer.from("SEKI", "ascii"), u32(0), Buffer.from([kind]), u32(payload.length), payload
]);
const moduleIdExtent = (bytes, start) => {
  let position = start;
  const parts = bytes.readUInt32BE(position); position += 4;
  for (let i = 0; i < parts; ++i) {
    const length = bytes.readUInt32BE(position); position += 4 + length;
  }
  return position + 4;
};
const moduleIdentityBytes = (moduleBytes) => {
  const start = 13 + 4;
  return moduleBytes.subarray(start, moduleIdExtent(moduleBytes, start));
};
const bundleParts = (bytes) => {
  const rootStart = 13;
  const rootEnd = moduleIdExtent(bytes, rootStart);
  const countOffset = rootEnd;
  const modules = [];
  let position = countOffset + 4;
  const count = bytes.readUInt32BE(countOffset);
  for (let i = 0; i < count; ++i) {
    const extent = 13 + bytes.readUInt32BE(position + 9);
    modules.push(bytes.subarray(position, position + extent));
    position += extent;
  }
  return { root: bytes.subarray(rootStart, rootEnd), modules };
};
const makeBundle = (root, modules) =>
  envelope(1, Buffer.concat([root, u32(modules.length), ...modules]));
const addImports = (moduleBytes, imports) => {
  let importsOffset = moduleIdExtent(moduleBytes, 13 + 4);
  const profileLength = moduleBytes.readUInt32BE(importsOffset);
  importsOffset += 4 + profileLength + 4;
  if (moduleBytes.readUInt32BE(importsOffset) !== 0) {
    throw new Error("addImport requires an empty import table");
  }
  const payloadOffset = importsOffset - 13;
  const oldPayload = moduleBytes.subarray(13);
  const encodedImports = imports.flatMap(([identity, digest]) =>
    [identity, Buffer.from([0]), digest]);
  const newPayload = Buffer.concat([
    oldPayload.subarray(0, payloadOffset),
    u32(imports.length), ...encodedImports,
    oldPayload.subarray(payloadOffset + 4)
  ]);
  return envelope(0, newPayload);
};
const addImport = (moduleBytes, importedIdentity, importedDigest) =>
  addImports(moduleBytes, [[importedIdentity, importedDigest]]);
const replaceAll = (bytes, oldValue, newValue) => {
  const result = Buffer.from(bytes);
  let position = 0;
  let replacements = 0;
  while ((position = result.indexOf(oldValue, position)) >= 0) {
    newValue.copy(result, position);
    position += oldValue.length;
    ++replacements;
  }
  if (replacements === 0) throw new Error("replacement target absent");
  return result;
};
const expectRejected = (name, bytes, reason) => {
  try {
    decodeBundle(bytes);
  } catch (error) {
    if (error instanceof AdmissionError && error.reason === reason) {
      console.log(`bundle_hostile=${name} reason=${reason}`);
      return;
    }
    throw error;
  }
  throw new Error(`${name}: bundle decoded; expected ${reason}`);
};

expectRejected("bundle-bytes-above-profile", Buffer.alloc(16777217), "0008");

const parts = bundleParts(bundle);
const baseDigest = moduleDigest(base);

const changedBase = Buffer.from(base);
const tokenAt = changedBase.indexOf(Buffer.from("Token", "ascii"));
if (tokenAt < 0) throw new Error("Token mutation target absent");
changedBase[tokenAt + 4] = "r".charCodeAt(0);
expectRejected("changed-dependency-bytes", makeBundle(parts.root,
  [changedBase, consumer]), "0405");

const substitutedConsumer = Buffer.from(consumer);
const digestAt = substitutedConsumer.indexOf(baseDigest);
if (digestAt < 0) throw new Error("import digest target absent");
substitutedConsumer[digestAt] ^= 1;
expectRejected("substituted-import-digest", makeBundle(parts.root,
  [base, substitutedConsumer]), "0405");

expectRejected("missing-dependency", makeBundle(parts.root, [consumer]), "0401");
expectRejected("reordered-modules", makeBundle(parts.root, [consumer, base]), "0104");
expectRejected("duplicate-module", makeBundle(parts.root,
  [base, base, consumer]), "0400");
expectRejected("unused-module", makeBundle(moduleIdentityBytes(base),
  [base, consumer]), "0402");

const changedProfileBase = replaceAll(base, Buffer.from("c11_bounded", "ascii"),
  Buffer.from("c11_boundec", "ascii"));
const changedProfileDigest = moduleDigest(changedProfileBase);
const changedProfileConsumer = replaceAll(consumer, baseDigest, changedProfileDigest);
expectRejected("profile-mismatch", makeBundle(parts.root,
  [changedProfileBase, changedProfileConsumer]), "0403");

const functionOrder = Buffer.from(
  "0000000000000000000000020000000000000001", "hex");
const functionOrderAt = consumer.lastIndexOf(functionOrder);
if (functionOrderAt < 0) throw new Error("function order target absent");
const badOrderConsumer = Buffer.from(consumer);
badOrderConsumer.writeUInt32BE(1, functionOrderAt + 12);
expectRejected("nonminimal-function-order", makeBundle(parts.root,
  [base, badOrderConsumer]), "0d04");

const importedType = Buffer.from("15010000000000000000", "hex");
const importedTypeAt = consumer.indexOf(importedType);
if (importedTypeAt < 0) throw new Error("imported type target absent");
const badImportIndexConsumer = Buffer.from(consumer);
badImportIndexConsumer.writeUInt32BE(1, importedTypeAt + 2);
expectRejected("import-index-out-of-range", makeBundle(parts.root,
  [base, badImportIndexConsumer]), "0406");

const unexportedTypeConsumer = Buffer.from(consumer);
unexportedTypeConsumer.writeUInt32BE(1, importedTypeAt + 6);
expectRejected("imported-type-not-exported", makeBundle(parts.root,
  [base, unexportedTypeConsumer]), "0408");

const importedCall = Buffer.from("1a010000000000000000", "hex");
const importedCallAt = consumer.indexOf(importedCall);
if (importedCallAt < 0) throw new Error("imported call target absent");
const unexportedFunctionConsumer = Buffer.from(consumer);
unexportedFunctionConsumer.writeUInt32BE(1, importedCallAt + 6);
expectRejected("imported-function-not-exported", makeBundle(parts.root,
  [base, unexportedFunctionConsumer]), "0408");

const cyclicBase = addImport(base, moduleIdentityBytes(consumer), moduleDigest(consumer));
expectRejected("identity-import-cycle", makeBundle(parts.root,
  [cyclicBase, consumer]), "0404");

const renamedBase = (index) => replaceAll(base, Buffer.from("base", "ascii"),
  Buffer.from(`b${String(index).padStart(3, "0")}`, "ascii"));
{
  const chain = [];
  for (let index = 0; index < 10; ++index) {
    let module = renamedBase(index);
    if (chain.length > 0) {
      const dependency = chain.at(-1);
      module = addImport(module, moduleIdentityBytes(dependency), moduleDigest(dependency));
    }
    chain.push(module);
  }
  expectRejected("dependency-depth-above-profile",
    makeBundle(moduleIdentityBytes(chain.at(-1)), chain), "040c");
}
{
  const graph = [];
  for (let index = 0; index < 13; ++index) {
    let module = renamedBase(index);
    module = addImports(module, graph.map((dependency) =>
      [moduleIdentityBytes(dependency), moduleDigest(dependency)]));
    graph.push(module);
  }
  expectRejected("import-edges-above-profile",
    makeBundle(moduleIdentityBytes(graph.at(-1)), graph), "040b");
}

console.log("scb0_import_bundle=verified positive=1 hostile=15");
