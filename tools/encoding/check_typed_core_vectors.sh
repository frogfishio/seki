#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
node tools/encoding/check_typed_core_vectors.mjs
