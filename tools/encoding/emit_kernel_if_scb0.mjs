// Experimental SCB-0 KernelIf fixture emitter. Not a compiler.
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
const bool = (out) => out.u8(1), u32 = (out) => out.u8(4);
const typeRef = (out, index) => { out.u8(0); out.u32(index); };
const rejection = (out) => { out.u8(22); typeRef(out, 0); };
const decision = (out) => { out.u8(20); u32(out); rejection(out); };
const local = (out, type, index) => { type(out); out.u8(4); out.u32(index); };
const bounds = (out, steps, live, depth, workspace = 0) => {
  out.u32(steps); out.u32(live); out.u32(depth); out.u32(workspace);
};

w.u32(0); w.seq(["seki", "fixtures", "kernel_if"], (part) => w.name(part));
w.u32(1); w.name("c11_bounded"); w.u32(1); w.u32(0); w.u32(0);
w.u32(1); w.name("Rejection"); w.u8(3); w.u32(1);
w.u32(0); w.name("No"); w.u8(0);
w.u32(0); // functions
w.u32(1); w.name("choose"); w.seq(["flag", "value"], (label) => w.name(label));
w.seq([bool, u32], (type) => type(w)); decision(w);
w.u32(1); typeRef(w, 0); w.u32(0); // rejection order
w.u8(4); // KernelIf
local(w, bool, 1);
w.u8(0); local(w, u32, 0); // accept
w.u8(1); rejection(w); w.u8(8); typeRef(w, 0); w.u32(0); w.u32(0); w.u32(0); // reject
bounds(w, 16, 256, 16); bounds(w, 5, 98, 4); w.u8(0);
w.u32(0); w.seq([0], (value) => w.u32(value)); w.u32(0); w.seq([0], (value) => w.u32(value));
w.seq([0, 1, 2, 3, 4], (value) => w.u8(value)); w.seq([0], (value) => w.u8(value));
w.u32(1048576); w.u32(1048576); w.u32(32); w.u32(4096); w.u32(65536); w.u32(256); w.u32(32);
bounds(w, 16777216, 8388608, 256, 8388608);
w.u32(0); w.seq([0], (value) => w.u32(value)); w.u32(0);

const payload = w.bytes(); const envelope = new Writer();
envelope.raw("SEKI"); envelope.u32(0); envelope.u8(0); envelope.u32(payload.length); envelope.raw(payload);
const bytes = envelope.bytes();
if (process.argv[2] === "--length") process.stdout.write(`${bytes.length}\n`);
else if (process.argv[2] === "--digest") process.stdout.write(`${createHash("sha256")
  .update("io.frogfish.seki/module/scb0/sha256", "ascii").update(Buffer.from([0]))
  .update(bytes).digest("hex")}\n`);
else process.stdout.write(bytes);
