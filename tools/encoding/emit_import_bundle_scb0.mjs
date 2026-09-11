// Experimental SCB-0 two-module bundle emitter. Not a compiler.
import { createHash } from "node:crypto";

class Writer {
  constructor() { this.parts = []; }
  u8(value) { this.parts.push(Buffer.from([value])); }
  u32(value) {
    const bytes = Buffer.alloc(4);
    bytes.writeUInt32BE(value);
    this.parts.push(bytes);
  }
  raw(value) { this.parts.push(Buffer.from(value)); }
  name(value) { const bytes = Buffer.from(value, "ascii"); this.u32(bytes.length); this.raw(bytes); }
  seq(values, emit) { this.u32(values.length); for (const value of values) emit(value); }
  bytes() { return Buffer.concat(this.parts); }
}

const baseId = [["seki", "fixtures", "base"], 1];
const consumerId = [["seki", "fixtures", "consumer"], 1];
const profile = ["c11_bounded", 1];

const emitModuleId = (w, [path, version]) => {
  w.seq(path, (part) => w.name(part)); w.u32(version);
};
const emitDigest = (w, digest) => { w.u8(0); w.raw(digest); };
const localTypeRef = (w, index) => { w.u8(0); w.u32(index); };
const importedTypeRef = (w, importIndex, index) => {
  w.u8(1); w.u32(importIndex); w.u32(index);
};
const localFunctionRef = (w, index) => { w.u8(0); w.u32(index); };
const importedFunctionRef = (w, importIndex, index) => {
  w.u8(1); w.u32(importIndex); w.u32(index);
};
const typeU32 = (w) => w.u8(4);
const typeLocalToken = (w) => { w.u8(21); localTypeRef(w, 0); };
const typeImportedToken = (w) => {
  w.u8(21); importedTypeRef(w, 0, 0);
};
const bounds = (w, steps, live, depth, workspace) => {
  w.u32(steps); w.u32(live); w.u32(depth); w.u32(workspace);
};
const moduleBounds = (w) => {
  w.u32(1048576); w.u32(32); w.u32(4096);
  w.u32(65536); w.u32(256); w.u32(32);
  bounds(w, 16777216, 8388608, 256, 8388608);
};
const functionKey = (w, base, labels) => {
  w.name(base); w.seq(labels, (label) => w.name(label));
};
const envelope = (kind, payload) => {
  const w = new Writer();
  w.raw("SEKI"); w.u32(0); w.u8(kind); w.u32(payload.length); w.raw(payload);
  return w.bytes();
};
const moduleDigest = (bytes) => createHash("sha256")
  .update("io.frogfish.seki/module/scb0/sha256", "ascii")
  .update(Buffer.from([0])).update(bytes).digest();

const modulePrefix = (w, identity) => {
  w.u32(0); emitModuleId(w, identity); w.name(profile[0]); w.u32(profile[1]);
};
const moduleSuffix = (w, exportTypes, exportFunctions, typeOrder, functionOrder) => {
  w.u32(0); // exported domains
  w.seq(exportTypes, (index) => w.u32(index));
  w.seq(exportFunctions, (index) => w.u32(index));
  w.u32(0); // exported kernels
  w.seq([0, 1, 2, 3], (tag) => w.u8(tag));
  w.seq([0], (tag) => w.u8(tag));
  moduleBounds(w);
  w.u32(0);
  w.seq(typeOrder, (index) => w.u32(index));
  w.seq(functionOrder, (index) => w.u32(index));
};

const emitLocalExpr = (w, emitType, index) => {
  emitType(w); w.u8(4); w.u32(index);
};
const emitCallExpr = (w, emitType, emitReference, emitArguments) => {
  emitType(w); w.u8(26); emitReference(w); emitArguments(w);
};

const baseModule = () => {
  const w = new Writer();
  modulePrefix(w, baseId);
  w.u32(0); // imports
  w.u32(0); // domains
  w.u32(1); // types
  w.name("Token"); w.u8(2); w.u32(1); w.name("value"); typeU32(w);
  w.u32(1); // functions
  functionKey(w, "keep", ["value"]);
  w.seq([0], () => typeLocalToken(w));
  typeLocalToken(w);
  emitLocalExpr(w, typeLocalToken, 0);
  bounds(w, 16, 128, 8, 0);
  bounds(w, 2, 64, 2, 0);
  w.u32(0); // kernels
  moduleSuffix(w, [0], [0], [0], [0]);
  return envelope(0, w.bytes());
};

const consumerModule = (baseDigest) => {
  const importedToken = (w) => typeImportedToken(w);
  const w = new Writer();
  modulePrefix(w, consumerId);
  w.u32(1); emitModuleId(w, baseId); emitDigest(w, baseDigest);
  w.u32(0); // domains
  w.u32(0); // types
  w.u32(2); // functions

  functionKey(w, "forward", ["value"]);
  w.seq([0], () => importedToken(w)); importedToken(w);
  emitCallExpr(w, importedToken,
    (out) => importedFunctionRef(out, 0, 0),
    (out) => out.seq([0], () => emitLocalExpr(out, importedToken, 0)));
  bounds(w, 32, 256, 16, 0); bounds(w, 5, 96, 4, 0);

  functionKey(w, "twice", ["value"]);
  w.seq([0], () => importedToken(w)); importedToken(w);
  emitCallExpr(w, importedToken,
    (out) => localFunctionRef(out, 0),
    (out) => out.seq([0], () => emitCallExpr(out, importedToken,
      (inner) => localFunctionRef(inner, 0),
      (inner) => inner.seq([0], () => emitLocalExpr(inner, importedToken, 0)))));
  bounds(w, 32, 256, 16, 0); bounds(w, 14, 128, 7, 0);

  w.u32(0); // kernels
  moduleSuffix(w, [], [0, 1], [], [0, 1]);
  return envelope(0, w.bytes());
};

const base = baseModule();
const baseDigest = moduleDigest(base);
const consumer = consumerModule(baseDigest);
const consumerDigest = moduleDigest(consumer);
const bundlePayload = new Writer();
emitModuleId(bundlePayload, consumerId);
bundlePayload.u32(2);
bundlePayload.raw(base);
bundlePayload.raw(consumer);
const bundle = envelope(1, bundlePayload.bytes());

const outputs = { base, baseDigest, consumer, consumerDigest, bundle };
const mode = process.argv[2] ?? "--bundle";
if (mode === "--base") process.stdout.write(outputs.base);
else if (mode === "--consumer") process.stdout.write(outputs.consumer);
else if (mode === "--bundle") process.stdout.write(outputs.bundle);
else if (mode === "--summary") process.stdout.write(`${JSON.stringify({
  base_length: base.length,
  base_sha256: baseDigest.toString("hex"),
  consumer_length: consumer.length,
  consumer_sha256: consumerDigest.toString("hex"),
  bundle_length: bundle.length,
  bundle_hex: bundle.toString("hex")
})}\n`);
else throw new Error(`unknown mode ${mode}`);
