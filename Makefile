.DEFAULT_GOAL := check

.PHONY: check verify-seed verify-status check-alpha-plan check-alpha-cli check-f0-candidate check-foundation-lock check-e0-vs1 check-e0-frontend check-e0-backend check-e0-manifest check-e0-lean check-encoding-vectors check-diff

check: verify-seed verify-status check-alpha-plan check-alpha-cli check-f0-candidate check-foundation-lock check-e0-vs1 check-e0-frontend check-e0-backend check-e0-manifest check-encoding-vectors check-diff

verify-seed:
	./SEKI_V0_3_PROJECT_SEED/VERIFY.sh

verify-status:
	node tools/check_project_status.mjs

check-alpha-plan:
	node tools/check_alpha_plan.mjs

check-alpha-cli:
	node tools/check_alpha_cli.mjs

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
