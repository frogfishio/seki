// Experimental SCB-0 construction/access fixture emitter. Not a compiler.
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
const unit = leaf(0), bool = leaf(1), u32 = leaf(4);
const index5 = (out) => { out.u8(14); out.u32(5); };
const optionU32 = (out) => { out.u8(15); u32(out); };
const resultU32Unit = (out) => { out.u8(16); u32(out); unit(out); };
const tupleU32Bool = (out) => { out.u8(17); out.seq([u32, bool], (type) => type(out)); };
const array4U32 = (out) => { out.u8(18); u32(out); out.u32(4); };
const local = (out, type, index) => { type(out); out.u8(4); out.u32(index); };
const bounds = (out, steps, live, depth, workspace = 0) => {
  out.u32(steps); out.u32(live); out.u32(depth); out.u32(workspace);
};
const head = (base, labels, parameters, output) => {
  w.name(base); w.seq(labels, (label) => w.name(label));
  w.seq(parameters, (type) => type(w)); output(w);
};
const tail = (steps, live, depth) => { bounds(w, 32, 512, 16); bounds(w, steps, live, depth); };

w.u32(0); w.seq(["seki", "fixtures", "construction_access"], (part) => w.name(part));
w.u32(1); w.name("c11_bounded"); w.u32(1);
w.u32(0); w.u32(0); w.u32(0); // imports, domains, types
w.u32(8);

head("arrayAt", ["items", "index"], [array4U32, u32], optionU32);
optionU32(w); w.u8(27); local(w, array4U32, 1); local(w, u32, 0); tail(4, 353, 3);

head("error", [], [], resultU32Unit);
resultU32Unit(w); w.u8(13); u32(w); unit(w); w.u8(0); tail(3, 33, 3);

head("indexEcho", ["value"], [index5], index5);
local(w, index5, 0); tail(2, 6, 2);

head("none", [], [], optionU32);
optionU32(w); w.u8(10); u32(w); tail(2, 33, 2);

head("ok", ["value"], [u32], resultU32Unit);
resultU32Unit(w); w.u8(12); unit(w); local(w, u32, 0); tail(3, 97, 3);

head("pair", ["value", "flag"], [u32, bool], tupleU32Bool);
tupleU32Bool(w); w.u8(9); w.u32(2); local(w, u32, 1); local(w, bool, 0); tail(4, 99, 3);

head("remember", ["value"], [u32], u32);
u32(w); w.u8(5); local(w, u32, 0); local(w, u32, 0); tail(4, 96, 3);

head("some", ["value"], [u32], optionU32);
optionU32(w); w.u8(11); local(w, u32, 0); tail(3, 97, 3);

w.u32(0); w.u32(0); w.u32(0);
w.seq([0, 1, 2, 3, 4, 5, 6, 7], (value) => w.u32(value)); w.u32(0);
w.seq([0, 1, 2, 3], (value) => w.u8(value)); w.seq([0], (value) => w.u8(value));
w.u32(1048576); w.u32(32); w.u32(4096); w.u32(65536); w.u32(256); w.u32(32);
bounds(w, 16777216, 8388608, 256, 8388608);
w.u32(0); w.u32(0); w.seq([0, 1, 2, 3, 4, 5, 6, 7], (value) => w.u32(value));

const payload = w.bytes(); const envelope = new Writer();
envelope.raw("SEKI"); envelope.u32(0); envelope.u8(0); envelope.u32(payload.length); envelope.raw(payload);
const bytes = envelope.bytes();
if (process.argv[2] === "--length") process.stdout.write(`${bytes.length}\n`);
else if (process.argv[2] === "--digest") process.stdout.write(`${createHash("sha256")
  .update("io.frogfish.seki/module/scb0/sha256", "ascii").update(Buffer.from([0]))
  .update(bytes).digest("hex")}\n`);
else process.stdout.write(bytes);
