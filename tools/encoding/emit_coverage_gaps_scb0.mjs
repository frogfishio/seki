// Experimental SCB-0 fixture closing the remaining tagged-form evidence gaps.
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
const bool = leaf(1), u8 = leaf(2), u16 = leaf(3), i8 = leaf(6), i16 = leaf(7);
const bytes3 = (out) => { out.u8(11); out.u32(3); };
const digest32 = (out) => { out.u8(13); out.u8(0); out.u32(32); };
const local = (out, type, index) => { type(out); out.u8(4); out.u32(index); };
const bounds = (out, steps, live, depth, workspace = 0) => {
  out.u32(steps); out.u32(live); out.u32(depth); out.u32(workspace);
};
const head = (base, labels, parameters, output) => {
  w.name(base); w.seq(labels, (label) => w.name(label));
  w.seq(parameters, (type) => type(w)); output(w);
};
const tail = (steps, live, depth) => { bounds(w, 16, 1024, 8); bounds(w, steps, live, depth); };

w.u32(0); w.seq(["seki", "fixtures", "coverage_gaps"], (part) => w.name(part));
w.u32(1); w.name("c11_bounded"); w.u32(1); w.u32(0); w.u32(0);
w.u32(1); w.name("ByteAlias"); w.u8(0); u8(w);
w.u32(8);

head("bytesLiteral", [], [], bytes3);
bytes3(w); w.u8(3); w.u32(3); w.raw([0x53, 0x45, 0x4b]); tail(2, 24, 2);

head("digestEcho", ["value"], [digest32], digest32);
local(w, digest32, 0); tail(2, 512, 2);

head("i16Echo", ["value"], [i16], i16);
local(w, i16, 0); tail(2, 32, 2);

head("i8Echo", ["value"], [i8], i8);
local(w, i8, 0); tail(2, 16, 2);

head("not", ["value"], [bool], bool);
bool(w); w.u8(16); local(w, bool, 0); tail(3, 3, 3);

head("notEqual", ["left", "right"], [u16, u16], bool);
bool(w); w.u8(15); local(w, u16, 1); local(w, u16, 0); tail(4, 65, 3);

head("orElse", ["left", "right"], [bool, bool], bool);
bool(w); w.u8(18); local(w, bool, 1); local(w, bool, 0); tail(4, 3, 3);

head("u16Echo", ["value"], [u16], u16);
local(w, u16, 0); tail(2, 32, 2);

w.u32(0); w.u32(0); w.seq([0], (value) => w.u32(value));
w.seq([0, 1, 2, 3, 4, 5, 6, 7], (value) => w.u32(value)); w.u32(0);
w.seq([0, 1, 2, 3], (value) => w.u8(value)); w.seq([0], (value) => w.u8(value));
w.u32(1048576); w.u32(1048576); w.u32(32); w.u32(4096); w.u32(65536); w.u32(256); w.u32(32);
bounds(w, 16777216, 8388608, 256, 8388608);
w.u32(0); w.seq([0], (value) => w.u32(value));
w.seq([0, 1, 2, 3, 4, 5, 6, 7], (value) => w.u32(value));

const payload = w.bytes(); const envelope = new Writer();
envelope.raw("SEKI"); envelope.u32(0); envelope.u8(0); envelope.u32(payload.length); envelope.raw(payload);
const moduleBytes = envelope.bytes();
if (process.argv[2] === "--length") process.stdout.write(`${moduleBytes.length}\n`);
else if (process.argv[2] === "--digest") process.stdout.write(`${createHash("sha256")
  .update("io.frogfish.seki/module/scb0/sha256", "ascii").update(Buffer.from([0]))
  .update(moduleBytes).digest("hex")}\n`);
else process.stdout.write(moduleBytes);
