#!/usr/bin/env bash
# The spike end to end. From the repository root or this directory:
#   experiments/kcore-gate/run.sh           check: reproducible, proved, checked, compiled, run
#   experiments/kcore-gate/run.sh emit      regenerate gen/ from the proved program
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GEN="$HERE/gen"
RT="$HERE/../../vendor/kcore/implementation/kcore-c"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
SUBSET=(-std=c11 -pedantic -Wall -Wextra -Werror)
STRICT=(-std=c11 -pedantic -Wall -Wextra -Werror -Wconversion -Wsign-conversion -Wshadow)

cd "$HERE"
lake build >/dev/null
emit() { lake exe emit "$@"; }

generate() { # dir
  emit text "$1/program.txt"
  pid=$(shasum -a 256 "$1/program.txt" | cut -d' ' -f1)
  emit c "$1" "$pid"
  emit adapter "$1"
  rm "$1/program.txt"
}

if [ "${1:-}" = "emit" ]; then
  mkdir -p "$GEN"; generate "$GEN"; echo "emitted into $GEN"; exit 0
fi

# 1. The committed files are exactly what the printer produces now.
mkdir -p "$tmp/fresh"; generate "$tmp/fresh"
for f in kc_u0.h kc_u0.c seki_a0_gate.h seki_a0_gate.c; do diff -u "$GEN/$f" "$tmp/fresh/$f"; done
echo "gate_emit=reproducible"

# 2. The theorem holds, on Lean's three standard axioms only.
printf 'import SekiSpike.Gate\n#print axioms SekiSpike.Gate.gate_run\n' > "$tmp/ax.lean"
axioms=$(lake env lean "$tmp/ax.lean")
echo "$axioms" | grep -q "depends on axioms: \[propext, Classical.choice, Quot.sound\]" \
  || { echo "unexpected axioms: $axioms" >&2; exit 1; }
if grep -nE '\bsorry\b|\badmit\b|native_decide' SekiSpike/*.lean Emit.lean; then exit 1; fi
echo "gate_theorem=verified axioms=propext,Classical.choice,Quot.sound"

# 3. KCore's independent checker accepts the emitted C against the proved program.
emit check "$GEN"

# 4. Compile: emitted C under KCore's subset flags, Seki's glue under Seki's.
emit vectors "$tmp/vectors.txt"
for profile in plain sanitizers; do
  extra=()
  [ "$profile" = sanitizers ] && extra=(-fsanitize=address,undefined -fno-sanitize-recover=all -g)
  cc "${SUBSET[@]}" ${extra[@]+"${extra[@]}"} -I"$RT" -c "$GEN/kc_u0.c" -o "$tmp/kc_u0.o"
  cc "${SUBSET[@]}" ${extra[@]+"${extra[@]}"} -c "$RT/kc_rt.c" -o "$tmp/kc_rt.o"
  cc "${STRICT[@]}" ${extra[@]+"${extra[@]}"} -I"$RT" -I"$GEN" -c "$GEN/seki_a0_gate.c" -o "$tmp/adapter.o"
  cc "${STRICT[@]}" ${extra[@]+"${extra[@]}"} -I"$GEN" -c "$HERE/test_gate.c" -o "$tmp/test.o"
  cc ${extra[@]+"${extra[@]}"} "$tmp/kc_u0.o" "$tmp/kc_rt.o" "$tmp/adapter.o" "$tmp/test.o" -o "$tmp/test_gate"
  # 5. Every vector's expected decision comes from the Lean statement.
  echo -n "profile=$profile "; "$tmp/test_gate" "$tmp/vectors.txt"
done
