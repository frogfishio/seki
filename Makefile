.DEFAULT_GOAL := check

.PHONY: alpha bundle check check-lean-proof check-host-boundary check-bundle check-quickstart verify-seed verify-status check-bootstrap-closure check-alpha-plan check-alpha-cli check-alpha-lexer check-alpha-parser check-alpha-checker check-host-boundary check-bundle check-quickstart check-f0-candidate check-foundation-lock check-kcore-vendor check-kcore-gate check-lean-proof check-e0-vs1 check-e0-frontend check-e0-backend check-e0-manifest check-e0-lean check-encoding-vectors check-diff

A0_CFLAGS = -std=c11 -pedantic -Wall -Wextra -Werror -Wconversion -Wsign-conversion -Wshadow -Wstrict-prototypes -Wmissing-prototypes -Wundef -Wformat=2
A0_SOURCES = src/alpha/sekic.c src/alpha/seki_lexer.c src/alpha/seki_parser.c \
  src/alpha/seki_types.c src/alpha/seki_checker.c src/alpha/seki_core.c \
  src/alpha/seki_c_backend.c

alpha: build/sekic

build/sekic: $(A0_SOURCES) src/alpha/seki_lexer.h src/alpha/seki_parser.h \
  src/alpha/seki_types.h src/alpha/seki_checker.h src/alpha/seki_core.h \
  src/alpha/seki_c_backend.h
	mkdir -p build
	$(CC) $(A0_CFLAGS) -Isrc/alpha $(A0_SOURCES) -o $@

check: verify-seed verify-status check-bootstrap-closure check-alpha-plan check-alpha-cli check-alpha-lexer check-alpha-parser check-alpha-checker check-host-boundary check-bundle check-quickstart check-f0-candidate check-foundation-lock check-kcore-vendor check-kcore-gate check-lean-proof check-e0-vs1 check-e0-frontend check-e0-backend check-e0-manifest check-encoding-vectors check-diff

verify-seed:
	./SEKI_V0_3_PROJECT_SEED/VERIFY.sh

verify-status:
	node tools/check_project_status.mjs

check-bootstrap-closure:
	node tools/check_bootstrap_closure.mjs

check-alpha-plan:
	node tools/check_alpha_plan.mjs

check-alpha-cli:
	node tools/check_alpha_cli.mjs

check-alpha-lexer:
	node tools/check_alpha_lexer.mjs

check-alpha-parser:
	node tools/check_alpha_parser.mjs

check-alpha-checker:
	node tools/check_alpha_checker.mjs

check-host-boundary:
	node tools/check_host_boundary.mjs

check-bundle:
	node tools/check_bundle.mjs

bundle:
	@mkdir -p build/bundle
	node tools/make_bundle.mjs $(KERNEL) build/bundle

check-quickstart:
	node tools/check_quickstart.mjs

check-f0-candidate:
	node tools/check_f0_candidate.mjs

check-foundation-lock:
	node tools/check_foundation_lock.mjs

check-e0-vs1:
	node tools/check_e0_vs1_contract.mjs
	node tools/encoding/check_e0_minimum_age_vector.mjs

check-e0-frontend:
	node tools/check_e0_frontend.mjs

check-e0-backend:
	node tools/check_e0_backend.mjs

check-e0-manifest:
	node tools/check_e0_manifest.mjs

# `lean-toolchain` pins the toolchain the foundation lock names, so elan
# resolves a bare `lean` to it. The check verifies that the installed binary
# was built from the locked commit before running the proof, and reports a
# skip when Lean is absent so the portfolio still runs in the pinned Node
# container.
check-kcore-vendor:
	node tools/check_kcore_vendor.mjs

check-kcore-gate:
	@if command -v lake >/dev/null 2>&1; then experiments/kcore-gate/run.sh; \
	else echo "kcore_gate=skipped reason=lake-not-available"; fi

check-lean-proof:
	node tools/check_lean_proof.mjs

check-e0-lean: check-lean-proof

check-encoding-vectors:
	./tools/encoding/check_minimal_vector.sh
	./tools/encoding/check_candidate_vector.sh
	./tools/encoding/check_decoder_vectors.sh
	./tools/encoding/check_import_bundle.sh
	./tools/encoding/check_typed_core_vectors.sh
	node tools/encoding/check_semantic_coverage.mjs

check-diff:
	git diff --check
