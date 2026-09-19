.DEFAULT_GOAL := check

.PHONY: alpha check verify-seed verify-status check-bootstrap-closure check-alpha-plan check-alpha-cli check-alpha-lexer check-alpha-parser check-alpha-checker check-f0-candidate check-foundation-lock check-e0-vs1 check-e0-frontend check-e0-backend check-e0-manifest check-e0-lean check-encoding-vectors check-diff

A0_CFLAGS = -std=c11 -pedantic -Wall -Wextra -Werror -Wconversion -Wsign-conversion -Wshadow -Wstrict-prototypes -Wmissing-prototypes -Wundef -Wformat=2
A0_SOURCES = src/alpha/sekic.c src/alpha/seki_lexer.c src/alpha/seki_parser.c src/alpha/seki_checker.c src/alpha/e0_frontend_adapter.c src/alpha/e0_backend_adapter.c

alpha: build/sekic

build/sekic: $(A0_SOURCES) src/alpha/e0_adapter.h src/alpha/seki_lexer.h src/alpha/seki_parser.h src/alpha/seki_checker.h src/e0/sekic_e0.c src/e0/seki_e0_c_backend.c
	mkdir -p build
	$(CC) $(A0_CFLAGS) -Isrc/alpha $(A0_SOURCES) -o $@

check: verify-seed verify-status check-bootstrap-closure check-alpha-plan check-alpha-cli check-alpha-lexer check-alpha-parser check-alpha-checker check-f0-candidate check-foundation-lock check-e0-vs1 check-e0-frontend check-e0-backend check-e0-manifest check-encoding-vectors check-diff

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

# Deliberately not part of `check` until the exact Lean 4.30.0 foundation is
# bound. Local execution is experimental evidence only.
check-e0-lean:
	lean formal/lean/E0/MinimumAge.lean

check-encoding-vectors:
	./tools/encoding/check_minimal_vector.sh
	./tools/encoding/check_candidate_vector.sh
	./tools/encoding/check_decoder_vectors.sh
	./tools/encoding/check_import_bundle.sh
	./tools/encoding/check_typed_core_vectors.sh
	node tools/encoding/check_semantic_coverage.mjs

check-diff:
	git diff --check
