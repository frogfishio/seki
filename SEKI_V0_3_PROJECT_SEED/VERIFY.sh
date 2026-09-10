#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$root"
shasum -a 256 -c SHA256SUMS
node VERIFY.mjs
