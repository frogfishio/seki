// Experimental SCB-0 minimal-module fixture emitter. Not a compiler.
import { createHash } from "node:crypto";

const chunks = [];
const u8 = (value) => chunks.push(Buffer.from([value]));
const u32 = (value) => {
  const bytes = Buffer.alloc(4);
  bytes.writeUInt32BE(value);
  chunks.push(bytes);
};
const raw = (value) => chunks.push(Buffer.from(value));
const name = (value) => {
  const bytes = Buffer.from(value, "ascii");
  u32(bytes.length);
  raw(bytes);
};
const emptySequence = () => u32(0);

const modulePayload = () => {
  chunks.length = 0;
  u32(0);                         // typed-core schema version
                                  // LanguageId: zero octets
  u32(1);                         // module path component count
  name("a");
  u32(1);                         // module version
  name("c11_bounded");
  u32(1);                         // profile version
  for (let i = 0; i < 5; ++i) emptySequence(); // imports through kernels
  for (let i = 0; i < 4; ++i) emptySequence(); // four export vectors
  emptySequence();                // theorem requirements
  emptySequence();                // claim ceiling
  u32(0);                         // maximum input bytes
  u32(1024);                      // maximum typed-core bytes
  for (let i = 0; i < 9; ++i) u32(0); // remaining module bounds
  u32(0);                         // derivation schema version
  emptySequence();                // type dependency order
  emptySequence();                // function dependency order
  return Buffer.concat(chunks);
};

const payload = modulePayload();
chunks.length = 0;
raw("SEKI");
u32(0);                           // SCB schema version
u8(0);                            // module object kind
u32(payload.length);
raw(payload);
const moduleBytes = Buffer.concat(chunks);

if (process.argv[2] === "--hex") {
  process.stdout.write(`${moduleBytes.toString("hex")}\n`);
} else if (process.argv[2] === "--digest") {
  const hash = createHash("sha256");
  hash.update("io.frogfish.seki/module/scb0/sha256", "ascii");
  hash.update(Buffer.from([0]));
  hash.update(moduleBytes);
  process.stdout.write(`${hash.digest("hex")}\n`);
} else {
  process.stdout.write(moduleBytes);
}

