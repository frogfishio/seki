.DEFAULT_GOAL := check

.PHONY: check verify-seed verify-status check-encoding-vectors check-diff

check: verify-seed verify-status check-encoding-vectors check-diff

verify-seed:
	./SEKI_V0_3_PROJECT_SEED/VERIFY.sh

verify-status:
	node tools/check_project_status.mjs

check-encoding-vectors:
	./tools/encoding/check_minimal_vector.sh
	./tools/encoding/check_candidate_vector.sh

check-diff:
	git diff --check
