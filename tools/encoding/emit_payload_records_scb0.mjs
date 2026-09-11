// Experimental SCB-0 record/payload fixture emitter. Not a compiler.
import { createHash } from "node:crypto";

class Writer {
  constructor() { this.parts = []; }
  u8(value) { this.parts.push(Buffer.from([value])); }
  u32(value) { const out = Buffer.alloc(4); out.writeUInt32BE(value); this.parts.push(out); }
  raw(value) { this.parts.push(Buffer.from(value)); }
  name(value) { const bytes = Buffer.from(value, "ascii"); this.u32(bytes.length); this.raw(bytes); }
  seq(values, emit) { this.u32(values.length); for (const value of values) emit(value); }
  bytes() { return Buffer.concat(this.parts); }
}

const w = new Writer();
const typeU32 = (out) => out.u8(4);
const typeRef = (out, index) => { out.u8(0); out.u32(index); };
const declared = (index) => (out) => { out.u8(22); typeRef(out, index); };
const pairType = declared(0);
const wrappedType = declared(1);
const variantRef = (out, owner, tag) => { typeRef(out, owner); out.u32(tag); };
const payloadType = (out) => { out.u8(21); variantRef(out, 1, 1); };
const bounds = (out, steps, live, depth, workspace) => {
  out.u32(steps); out.u32(live); out.u32(depth); out.u32(workspace);
};
const local = (out, type, index) => { type(out); out.u8(4); out.u32(index); };
const fieldRef = (out, ownerKind, owner, tag, index) => {
  out.u8(ownerKind);
  if (ownerKind === 0) typeRef(out, owner);
  else variantRef(out, owner, tag);
  out.u32(index);
};
const project = (out, resultType, record, ownerKind, owner, tag, index) => {
  resultType(out); out.u8(7); record(out); fieldRef(out, ownerKind, owner, tag, index);
};
const functionKey = (out, base, labels) => {
  out.name(base); out.seq(labels, (label) => out.name(label));
};

w.u32(0);
w.seq(["seki", "fixtures", "payload_records"], (part) => w.name(part)); w.u32(1);
w.name("c11_bounded"); w.u32(1);
w.u32(0); // imports
w.u32(0); // domains
w.u32(2); // types
w.name("Pair"); w.u8(2); w.u32(2);
w.name("left"); typeU32(w); w.name("right"); typeU32(w);
w.name("Wrapped"); w.u8(3); w.u32(2);
w.u32(0); w.name("Empty"); w.u8(0);
w.u32(1); w.name("Pair"); w.u8(1); w.u32(2);
w.name("left"); typeU32(w); w.name("right"); typeU32(w);

w.u32(3); // functions, in FunctionKey order
functionKey(w, "leftOrZero", ["wrapped"]);
w.seq([0], () => wrappedType(w)); typeU32(w);
typeU32(w); w.u8(25); local(w, wrappedType, 0); w.u32(2);
w.u8(0); typeRef(w, 1); w.u32(0); // Wrapped::Empty constructor
typeU32(w); w.u8(2); w.u8(2); w.raw(Buffer.alloc(4));
w.u8(0); typeRef(w, 1); w.u32(1); // Wrapped::Pair constructor
project(w, typeU32, (out) => local(out, payloadType, 0), 1, 1, 1, 0);
bounds(w, 32, 512, 16, 0); bounds(w, 5, 290, 4, 0);

functionKey(w, "makePair", ["left", "right"]);
w.seq([0, 1], () => typeU32(w)); pairType(w);
pairType(w); w.u8(6); typeRef(w, 0); w.u32(2);
fieldRef(w, 0, 0, 0, 0); local(w, typeU32, 1);
fieldRef(w, 0, 0, 0, 1); local(w, typeU32, 0);
bounds(w, 32, 512, 16, 0); bounds(w, 4, 192, 3, 0);

functionKey(w, "wrapPair", ["pair"]);
w.seq([0], () => pairType(w)); wrappedType(w);
wrappedType(w); w.u8(8); variantRef(w, 1, 1); w.u32(2);
w.name("left"); project(w, typeU32, (out) => local(out, pairType, 0), 0, 0, 0, 0);
w.name("right"); project(w, typeU32, (out) => local(out, pairType, 0), 0, 0, 0, 1);
bounds(w, 32, 512, 16, 0); bounds(w, 6, 193, 4, 0);

w.u32(0); // kernels
w.u32(0); // exported domains
w.seq([0, 1], (value) => w.u32(value));
w.seq([0, 1, 2], (value) => w.u32(value));
w.u32(0); // exported kernels
w.seq([0, 1, 2, 3], (value) => w.u8(value));
w.seq([0], (value) => w.u8(value));
w.u32(1048576); w.u32(1048576); w.u32(32); w.u32(4096);
w.u32(65536); w.u32(256); w.u32(32); bounds(w, 16777216, 8388608, 256, 8388608);
w.u32(0); w.seq([0, 1], (value) => w.u32(value));
w.seq([0, 1, 2], (value) => w.u32(value));

const payload = w.bytes();
const envelope = new Writer();
envelope.raw("SEKI"); envelope.u32(0); envelope.u8(0); envelope.u32(payload.length); envelope.raw(payload);
const bytes = envelope.bytes();
if (process.argv[2] === "--length") process.stdout.write(`${bytes.length}\n`);
else if (process.argv[2] === "--digest") process.stdout.write(`${createHash("sha256")
  .update("io.frogfish.seki/module/scb0/sha256", "ascii")
  .update(Buffer.from([0])).update(bytes).digest("hex")}\n`);
else process.stdout.write(bytes);
