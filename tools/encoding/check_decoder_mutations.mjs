import fs from "node:fs";
import { AdmissionError, decodeModule } from "./decode_scb0.mjs";

const vectorBytes = (path) => {
  const vector = JSON.parse(fs.readFileSync(path, "utf8"));
  return Buffer.from(vector.module_hex, "hex");
};

const minimal = vectorBytes("spec/encoding/vectors/minimal-module-v0.json");
const candidate = vectorBytes("spec/encoding/vectors/candidate-selection-v0.json");

const uniqueOffset = (bytes, pattern, label) => {
  const first = bytes.indexOf(pattern);
  if (first < 0 || bytes.indexOf(pattern, first + 1) >= 0) {
    throw new Error(`${label}: mutation pattern is not unique`);
  }
  return first;
};

const changed = (bytes, mutate) => {
  const copy = Buffer.from(bytes);
  mutate(copy);
  return copy;
};

const expectDecoded = (name, bytes) => {
  decodeModule(bytes);
  process.stdout.write(`decoder_positive=${name}\n`);
};

const expectRejected = (name, bytes, expected) => {
  try {
    decodeModule(bytes);
  } catch (error) {
    if (error instanceof AdmissionError && error.reason === expected) {
      process.stdout.write(`decoder_hostile=${name} reason=${expected}\n`);
      return;
    }
    throw error;
  }
  throw new Error(`${name}: mutation decoded; expected ${expected}`);
};

expectDecoded("minimal-module-v0", minimal);
expectDecoded("candidate-selection-v0", candidate);

expectRejected("module-envelope-bytes-above-profile", Buffer.alloc(1048577), "0000");
expectRejected("bad-magic", changed(candidate, (b) => { b[0] ^= 1; }), "0001");
expectRejected("unsupported-version", changed(candidate, (b) => {
  b.writeUInt32BE(1, 4);
}), "0002");
expectRejected("wrong-object-kind", changed(candidate, (b) => { b[8] = 1; }), "0003");
expectRejected("truncated-envelope", candidate.subarray(0, candidate.length - 1), "0005");
expectRejected("trailing-byte", Buffer.concat([candidate, Buffer.from([0])]), "0006");
expectRejected("wrong-core-schema", changed(candidate, (b) => {
  b.writeUInt32BE(1, 13);
}), "0200");

const candidateDecl = Buffer.from("0000000943616e64696461746502", "hex");
const candidateDeclAt = uniqueOffset(candidate, candidateDecl, "Candidate body tag");
expectRejected("unknown-type-declaration-tag", changed(candidate, (b) => {
  b[candidateDeclAt + candidateDecl.length - 1] = 0xff;
}), "0100");

const candidateIdName = Buffer.from("0000000b43616e6469646174654964", "hex");
const candidateIdAt = uniqueOffset(candidate, candidateIdName, "CandidateId key");
expectRejected("decreasing-type-key", changed(candidate, (b) => {
  Buffer.from("AAAAAAAAAAA", "ascii").copy(b, candidateIdAt + 4);
}), "0104");

expectRejected("key-order-precedes-later-value-tag", changed(candidate, (b) => {
  Buffer.from("AAAAAAAAAAA", "ascii").copy(b, candidateIdAt + 4);
  b[candidateIdAt + candidateIdName.length] = 0xff;
}), "0104");

const missingPayload = Buffer.from("00000001000000074d697373696e6700", "hex");
const missingAt = uniqueOffset(candidate, missingPayload, "Missing payload option");
expectRejected("invalid-option-tag", changed(candidate, (b) => {
  b[missingAt + missingPayload.length - 1] = 2;
}), "0102");

const theoremSet = Buffer.from("000000050001020304", "hex");
const theoremAt = uniqueOffset(candidate, theoremSet, "theorem set");
expectRejected("duplicate-theorem", changed(candidate, (b) => {
  b[theoremAt + 5] = 0;
}), "0105");

const boundsAndPublication = Buffer.from(
  "00000800000080000000004000001000" +
  "000000d400004ba100000008000000c900", "hex"
);
const publicationAt = uniqueOffset(candidate, boundsAndPublication,
  "kernel bounds and publication flag") + boundsAndPublication.length - 1;
expectRejected("invalid-publication-boolean", changed(candidate, (b) => {
  b[publicationAt] = 2;
}), "0101");

const typeOrderTail = Buffer.from(
  "0000000000000005000000010000000200000000000000030000000400000000", "hex"
);
const typeOrderAt = uniqueOffset(candidate, typeOrderTail, "derivation orders");
expectRejected("nonminimal-type-order", changed(candidate, (b) => {
  b.writeUInt32BE(4, typeOrderAt + 8);
}), "0d02");

const competing = changed(candidate, (b) => {
  b[0] ^= 1;
  b[candidateDeclAt + candidateDecl.length - 1] = 0xff;
});
expectRejected("envelope-precedes-shape", competing, "0001");

const canonicalCompeting = changed(candidate, (b) => {
  b[candidateDeclAt + candidateDecl.length - 1] = 0xff;
  b[theoremAt + 5] = 0;
});
expectRejected("earlier-path-within-canonical-layer", canonicalCompeting, "0100");

console.log("scb0_decoder_mutations=verified positives=2 hostile=16");
