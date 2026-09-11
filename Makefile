.DEFAULT_GOAL := check

.PHONY: check verify-seed verify-status check-diff

check: verify-seed verify-status check-diff

verify-seed:
	./SEKI_V0_3_PROJECT_SEED/VERIFY.sh

verify-status:
	node tools/check_project_status.mjs

check-diff:
	git diff --check

