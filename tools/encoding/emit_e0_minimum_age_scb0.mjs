// Experimental E0-VS1 SCB-0 fixture emitter. Not a source compiler.
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
  name(value) {
    const bytes = Buffer.from(value, "ascii");
    this.u32(bytes.length);
    this.raw(bytes);
  }
  seq(values, emit) {
    this.u32(values.length);
    for (const value of values) emit(value);
  }
  bytes() { return Buffer.concat(this.parts); }
}

const w = new Writer();
const unit = out => out.u8(0);
const bool = out => out.u8(1);
const u8 = out => out.u8(2);
const typeRef = (out, index) => { out.u8(0); out.u32(index); };
const declared = (out, index) => { out.u8(21); typeRef(out, index); };
const applicant = out => declared(out, 0);
const rejection = out => declared(out, 1);
const decision = out => { out.u8(19); unit(out); rejection(out); };
const fieldRef = (out, owner, index) => {
  out.u8(0); typeRef(out, owner); out.u32(index);
};
const expr = (out, type, term) => { type(out); term(out); };
const local = (out, type, index) => expr(out, type, value => {
  value.u8(4); value.u32(index);
});
const bounds = (out, steps, live, depth, workspace = 0) => {
  out.u32(steps); out.u32(live); out.u32(depth); out.u32(workspace);
};

w.u32(0); // typed-core schema version
w.seq(["seki", "experiments", "minimum_age"], part => w.name(part));
w.u32(1);
w.name("c11_bounded"); w.u32(1);

w.u32(0); // imports
w.u32(0); // domains
w.u32(2); // types
w.name("Applicant"); w.u8(2); w.u32(1); // record, one field
w.name("age"); u8(w);
w.name("Rejection"); w.u8(3); w.u32(1); // variant, one case
w.u32(1); w.name("Underage"); w.u8(0); // stable tag, name, no payload
w.u32(0); // functions

w.u32(1); // kernels
w.name("decide"); w.seq(["applicant"], label => w.name(label));
w.seq([applicant], type => type(w));
decision(w);
w.u32(1); typeRef(w, 1); w.u32(1); // rejection order

w.u8(4); // KernelIf
expr(w, bool, out => {
  out.u8(19); out.u8(0); // Compare(LessThan)
  expr(out, u8, project => {
    project.u8(7);
    local(project, applicant, 0);
    fieldRef(project, 0, 0);
  });
  expr(out, u8, literal => {
    literal.u8(2); literal.u8(0); literal.u8(18); // IntLit(U8, 18)
  });
});
w.u8(1); // KernelReject
expr(w, rejection, out => {
  out.u8(8); typeRef(out, 1); out.u32(1); out.u32(0);
});
w.u32(0); // precedence index
w.u8(0); // KernelAccept
expr(w, unit, out => out.u8(0));

bounds(w, 32, 256, 16, 0);
bounds(w, 8, 25, 5, 0);
w.u8(0); // publication_eligible

w.u32(0); // exported domains
w.seq([0, 1], value => w.u32(value)); // exported types
w.u32(0); // exported functions
w.seq([0], value => w.u32(value)); // exported kernels
w.seq([0, 1, 2, 3, 4], value => w.u8(value)); // theorem requirements
w.seq([0, 1, 3], value => w.u8(value)); // claim ceiling

w.u32(1048576); w.u32(32); w.u32(4096); w.u32(65536); w.u32(256); w.u32(32);
bounds(w, 16777216, 8388608, 256, 8388608);
w.u32(0); // derivation schema
w.seq([0, 1], value => w.u32(value));
w.u32(0); // function dependency order

const payload = w.bytes();
const envelope = new Writer();
envelope.raw("SEKI"); envelope.u32(0); envelope.u8(0);
envelope.u32(payload.length); envelope.raw(payload);
const bytes = envelope.bytes();

if (process.argv[2] === "--hex") {
  process.stdout.write(`${bytes.toString("hex")}\n`);
} else if (process.argv[2] === "--length") {
  process.stdout.write(`${bytes.length}\n`);
} else if (process.argv[2] === "--digest") {
  process.stdout.write(`${createHash("sha256")
    .update("io.frogfish.seki/module/scb0/sha256", "ascii")
    .update(Buffer.from([0]))
    .update(bytes).digest("hex")}\n`);
} else {
  process.stdout.write(bytes);
}
