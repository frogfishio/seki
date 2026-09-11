#!/bin/sh
set -eu

seki_vector_tmp=$(mktemp -d /tmp/seki-scb0.XXXXXX)
trap 'rm -f "$seki_vector_tmp/emit-c" "$seki_vector_tmp/c.scb0" "$seki_vector_tmp/js.scb0"; rmdir "$seki_vector_tmp"' EXIT HUP INT TERM

cc -std=c11 -Wall -Wextra -Werror -pedantic \
  tools/encoding/emit_minimal_scb0.c -o "$seki_vector_tmp/emit-c"
"$seki_vector_tmp/emit-c" > "$seki_vector_tmp/c.scb0"
node tools/encoding/emit_minimal_scb0.mjs > "$seki_vector_tmp/js.scb0"
node tools/encoding/check_minimal_vector.mjs \
  "$seki_vector_tmp/c.scb0" "$seki_vector_tmp/js.scb0" \
  spec/encoding/vectors/minimal-module-v0.json

node_digest=$(node tools/encoding/emit_minimal_scb0.mjs --digest)
openssl_digest=$(
  (printf 'io.frogfish.seki/module/scb0/sha256\000'; cat "$seki_vector_tmp/c.scb0") |
    openssl dgst -sha256 | awk '{print $2}'
)
test "$node_digest" = "$openssl_digest"
