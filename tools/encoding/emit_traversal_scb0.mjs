// Experimental SCB-0 bounded-traversal fixture emitter. Not a compiler.
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
const leaf = (tag) => (out) => out.u8(tag);
const bool = leaf(1), u32 = leaf(4);
const array = (item) => (out) => { out.u8(18); item(out); out.u32(4); };
const vec = (item) => (out) => { out.u8(19); item(out); out.u32(4); };
const arrayBool = array(bool), arrayU32 = array(u32), vecU32 = vec(u32);
const local = (out, type, index) => { type(out); out.u8(4); out.u32(index); };
const literalTrue = (out) => { bool(out); out.u8(1); out.u8(1); };
const bounds = (out, steps, live, depth, workspace = 0) => {
  out.u32(steps); out.u32(live); out.u32(depth); out.u32(workspace);
};
const head = (base, labels, parameters, output) => {
  w.name(base); w.seq(labels, (label) => w.name(label));
  w.seq(parameters, (type) => type(w)); output(w);
};
const tail = (steps, live, depth, workspace) => {
  bounds(w, 64, 1024, 16, 512); bounds(w, steps, live, depth, workspace);
};
const block = (parameters, result, body) => {
  w.seq(parameters, (type) => type(w)); result(w); body(w);
};
const unaryTraversal = (tag, collectionType, outputType, blockParameters,
  blockResult, blockBody) => {
  outputType(w); w.u8(tag); local(w, collectionType, 0);
  block(blockParameters, blockResult, blockBody);
};

w.u32(0); w.seq(["seki", "fixtures", "traversal"], (part) => w.name(part));
w.u32(1); w.name("c11_bounded"); w.u32(1); w.u32(0); w.u32(0); w.u32(0);
w.u32(7);

head("all", ["items"], [arrayBool], bool);
unaryTraversal(32, arrayBool, bool, [bool], bool, (out) => local(out, bool, 0));
tail(11, 10, 4, 4);

head("any", ["items"], [arrayBool], bool);
unaryTraversal(33, arrayBool, bool, [bool], bool, (out) => local(out, bool, 0));
tail(11, 10, 4, 4);

head("filterArray", ["items"], [arrayU32], vecU32);
unaryTraversal(35, arrayU32, vecU32, [u32], bool, literalTrue);
tail(11, 289, 4, 134);

head("filterVec", ["items"], [vecU32], vecU32);
unaryTraversal(35, vecU32, vecU32, [u32], bool, literalTrue);
tail(11, 295, 4, 134);

head("fold", ["items", "initial"], [arrayU32, u32], u32);
u32(w); w.u8(30); local(w, arrayU32, 1); local(w, u32, 0);
block([u32, u32], u32, (out) => local(out, u32, 1));
tail(12, 416, 4, 35);

head("mapArray", ["items"], [arrayU32], arrayU32);
unaryTraversal(34, arrayU32, arrayU32, [u32], u32, (out) => local(out, u32, 0));
tail(11, 320, 4, 131);

head("mapVec", ["items"], [vecU32], vecU32);
unaryTraversal(34, vecU32, vecU32, [u32], u32, (out) => local(out, u32, 0));
tail(11, 326, 4, 134);

w.u32(0); w.u32(0); w.u32(0);
w.seq([0, 1, 2, 3, 4, 5, 6], (value) => w.u32(value)); w.u32(0);
w.seq([0, 1, 2, 3], (value) => w.u8(value)); w.seq([0], (value) => w.u8(value));
w.u32(1048576); w.u32(1048576); w.u32(32); w.u32(4096); w.u32(65536); w.u32(256); w.u32(32);
bounds(w, 16777216, 8388608, 256, 8388608);
w.u32(0); w.u32(0); w.seq([0, 1, 2, 3, 4, 5, 6], (value) => w.u32(value));

const payload = w.bytes(); const envelope = new Writer();
envelope.raw("SEKI"); envelope.u32(0); envelope.u8(0); envelope.u32(payload.length); envelope.raw(payload);
const bytes = envelope.bytes();
if (process.argv[2] === "--length") process.stdout.write(`${bytes.length}\n`);
else if (process.argv[2] === "--digest") process.stdout.write(`${createHash("sha256")
  .update("io.frogfish.seki/module/scb0/sha256", "ascii").update(Buffer.from([0]))
  .update(bytes).digest("hex")}\n`);
else process.stdout.write(bytes);
