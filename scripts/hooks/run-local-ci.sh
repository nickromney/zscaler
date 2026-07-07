#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/hooks/lib.sh
source "${SCRIPT_DIR}/lib.sh"

hook_parse_execute_flag "$@"
if [[ "${#HOOK_ARGS[@]}" -gt 0 ]]; then
  hook_fail "unexpected arguments: ${HOOK_ARGS[*]}"
  exit 1
fi

if hook_skip_requested; then
  hook_print_skip_and_exit
fi

if [[ "${ZSCALER_LOCAL_CI_IN_PROGRESS:-}" == "1" ]]; then
  hook_warn "ZSCALER_LOCAL_CI_IN_PROGRESS=1; skipping run-local-ci.sh to avoid recursive local CI"
  exit 0
fi

cd "${HOOKS_REPO_ROOT}"

cat <<'EOF'
Zscaler pre-push local CI gate

Running the same checks as .github/workflows/test.yml:
  shellcheck zscaler-mac.sh
  find _test -name "*.bash" -o -name "*.bats" | xargs shellcheck || true
  ./_test/run_tests.sh
  ./zscaler-mac.sh --help
  ./zscaler-mac.sh --dry-run --azure-cli --profile

Skip only when you have a reason:
  LEFTHOOK=0 git push
  ZSCALER_SKIP_HOOKS=1 git push
  git push --no-verify
EOF

export ZSCALER_LOCAL_CI_IN_PROGRESS=1
failed_gate=""

# shellcheck disable=SC2038 # Keep this command aligned with the existing GitHub Actions workflow.
if ! shellcheck zscaler-mac.sh; then
  failed_gate="shellcheck zscaler-mac.sh"
elif ! find _test -name "*.bash" -o -name "*.bats" | xargs shellcheck; then
  hook_warn "test shellcheck findings are advisory to match GitHub Actions"
elif ! ./_test/run_tests.sh; then
  failed_gate="./_test/run_tests.sh"
elif ! ./zscaler-mac.sh --help >/dev/null; then
  failed_gate="./zscaler-mac.sh --help"
elif ! ./zscaler-mac.sh --dry-run --azure-cli --profile; then
  failed_gate="./zscaler-mac.sh --dry-run --azure-cli --profile"
fi

if [[ -n "${failed_gate}" ]]; then
  hook_fail "pre-push gate failed: ${failed_gate}"
  exit 1
fi

hook_ok "pre-push gate passed"
