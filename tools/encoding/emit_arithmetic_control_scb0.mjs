// Experimental SCB-0 arithmetic/control fixture emitter. Not a compiler.
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
const bool = leaf(1), u32 = leaf(4), i32 = leaf(8), i64 = leaf(9), arithmeticError = leaf(10);
const result = (ok) => (out) => { out.u8(16); ok(out); arithmeticError(out); };
const resultU32 = result(u32), resultI32 = result(i32);
const local = (out, type, index) => { type(out); out.u8(4); out.u32(index); };
const bounds = (out, steps, live, depth, workspace = 0) => {
  out.u32(steps); out.u32(live); out.u32(depth); out.u32(workspace);
};
const functionKey = (out, base, labels) => {
  out.name(base); out.seq(labels, (label) => out.name(label));
};
const functionHead = (name, labels, parameters, output) => {
  functionKey(w, name, labels); w.seq(parameters, (type) => type(w)); output(w);
};
const functionTail = (steps, live, depth) => {
  bounds(w, 32, 512, 16); bounds(w, steps, live, depth);
};
const binary = (output, tag, prefix, leftType, rightType = leftType) => {
  output(w); w.u8(tag); for (const byte of prefix) w.u8(byte);
  local(w, leftType, 1); local(w, rightType, 0);
};

w.u32(0); w.seq(["seki", "fixtures", "arithmetic_control"], (part) => w.name(part));
w.u32(1); w.name("c11_bounded"); w.u32(1);
w.u32(0); w.u32(0); w.u32(0); // imports, domains, types
w.u32(9);

functionHead("addChecked", ["left", "right"], [u32, u32], resultU32);
binary(resultU32, 20, [0, 0], u32); functionTail(4, 161, 3);

functionHead("addWrapping", ["left", "right"], [u32, u32], u32);
binary(u32, 20, [1, 0], u32); functionTail(4, 160, 3);

functionHead("both", ["left", "right"], [bool, bool], bool);
binary(bool, 17, [], bool); functionTail(4, 3, 3);

functionHead("choose", ["condition", "yes", "no"], [bool, u32, u32], u32);
u32(w); w.u8(24); local(w, bool, 2); local(w, u32, 1); local(w, u32, 0);
functionTail(4, 97, 3);

functionHead("convertSaturating", ["value"], [i64], i32);
i32(w); w.u8(23); w.u8(2); w.u8(6); local(w, i64, 0);
functionTail(3, 160, 3);

functionHead("divideWrapping", ["left", "right"], [u32, u32], resultU32);
binary(resultU32, 20, [1, 3], u32); functionTail(4, 161, 3);

functionHead("less", ["left", "right"], [u32, u32], bool);
binary(bool, 19, [0], u32); functionTail(4, 129, 3);

functionHead("negateChecked", ["value"], [i32], resultI32);
resultI32(w); w.u8(21); w.u8(0); w.u8(0); local(w, i32, 0);
functionTail(3, 97, 3);

functionHead("shiftChecked", ["value", "count"], [u32, u32], resultU32);
resultU32(w); w.u8(22); w.u8(0); w.u8(0); local(w, u32, 1); local(w, u32, 0);
functionTail(4, 161, 3);

w.u32(0); // kernels
w.u32(0); w.u32(0); // exported domains, types
w.seq([0, 1, 2, 3, 4, 5, 6, 7, 8], (value) => w.u32(value));
w.u32(0); // exported kernels
w.seq([0, 1, 2, 3], (value) => w.u8(value)); w.seq([0], (value) => w.u8(value));
w.u32(1048576); w.u32(32); w.u32(4096); w.u32(65536); w.u32(256); w.u32(32);
bounds(w, 16777216, 8388608, 256, 8388608);
w.u32(0); w.u32(0); // derivation schema, empty type order
w.seq([0, 1, 2, 3, 4, 5, 6, 7, 8], (value) => w.u32(value));

const payload = w.bytes(); const envelope = new Writer();
envelope.raw("SEKI"); envelope.u32(0); envelope.u8(0); envelope.u32(payload.length); envelope.raw(payload);
const bytes = envelope.bytes();
if (process.argv[2] === "--length") process.stdout.write(`${bytes.length}\n`);
else if (process.argv[2] === "--digest") process.stdout.write(`${createHash("sha256")
  .update("io.frogfish.seki/module/scb0/sha256", "ascii").update(Buffer.from([0]))
  .update(bytes).digest("hex")}\n`);
else process.stdout.write(bytes);
