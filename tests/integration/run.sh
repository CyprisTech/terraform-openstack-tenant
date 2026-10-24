#!/usr/bin/env bash
# Integration tests on a real OpenStack cloud.
#
#   ./run.sh <stage> <plan|apply|check|destroy|full>
#
#   plan     show what would be created (no change)
#   apply    create the resources (asks for confirmation unless AUTO_APPROVE=1)
#   check    plan again and fail if anything would change (expected: empty plan)
#   destroy  delete everything the stage created (asks unless AUTO_APPROVE=1)
#   full     apply, check, then destroy; destroy also runs if check fails
#
# Environment:
#   OS_CLOUD      entry of clouds.yaml to use (default: tf-module-test)
#   TOOL          tofu or terraform (default: tofu)
#   AUTO_APPROVE  1 to skip confirmations
#
# Every other OS_* variable is unset, so that credentials can only come from
# the clouds.yaml entry. State is local, in the stage directory (git-ignored).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
stage="${1:?usage: run.sh <stage> <plan|apply|check|destroy|full>}"
action="${2:?usage: run.sh <stage> <plan|apply|check|destroy|full>}"
dir="$here/${stage%/}"
[[ -d "$dir" ]] || { echo "unknown stage: $stage" >&2; exit 2; }
[[ -f "$here/env.tfvars" ]] || { echo "missing $here/env.tfvars (copy env.tfvars.example)" >&2; exit 2; }

cloud="${OS_CLOUD:-tf-module-test}"
for v in $(compgen -e | grep '^OS_' || true); do unset "$v"; done
export OS_CLOUD="$cloud"

tool="${TOOL:-tofu}"
vars=(-input=false -var-file="$here/env.tfvars")
approve=()
[[ "${AUTO_APPROVE:-0}" == "1" ]] && approve=(-auto-approve)

mkdir -p "$here/.logs"
log="$here/.logs/$(basename "$dir")-$(date -u +%Y%m%dT%H%M%SZ)-$action.log"
exec > >(tee -a "$log") 2>&1
echo "== stage=$(basename "$dir") action=$action tool=$tool cloud=$OS_CLOUD log=$log"

cd "$dir"
"$tool" init -input=false >/dev/null

# Summary written next to the log at the end of every run (git-ignored too).
# Release notes in docs/testing.md are compiled from these summaries.
started=$(date -u +%Y-%m-%dT%H:%M:%SZ); t0=$(date +%s)
r_apply="-"; r_check="-"; r_destroy="-"
summary() {
  local tool_version provider_version
  tool_version=$("$tool" version 2>/dev/null | head -1)
  provider_version=$(grep -A1 'terraform-provider-openstack/openstack' .terraform.lock.hcl 2>/dev/null | sed -n 's/.*version *= *"\(.*\)"/\1/p' | head -1)
  cat > "${log%.log}.summary.json" <<JSON
{"stage": "$(basename "$dir")", "action": "$action", "started": "$started", "duration_s": $(( $(date +%s) - t0 )),
 "tool": "$tool_version", "provider": "${provider_version:-unknown}",
 "apply": "$r_apply", "check": "$r_check", "destroy": "$r_destroy"}
JSON
  echo "== summary: apply=$r_apply check=$r_check destroy=$r_destroy ($(( $(date +%s) - t0 ))s)"
}
trap summary EXIT

check() {
  set +e
  "$tool" plan -detailed-exitcode "${vars[@]}"
  rc=$?
  set -e
  case $rc in
    0) echo "== CHECK OK: empty plan after apply" ; r_check=ok ;;
    2) echo "== CHECK FAILED: the plan after apply is not empty" ; r_check=failed ; return 1 ;;
    *) echo "== CHECK ERROR: plan failed" ; r_check=error ; return 1 ;;
  esac
}

case "$action" in
  plan)    "$tool" plan "${vars[@]}" ;;
  apply)   if "$tool" apply "${vars[@]}" "${approve[@]}"; then r_apply=ok; else r_apply=failed; exit 1; fi ;;
  check)   check ;;
  destroy) if "$tool" destroy "${vars[@]}" "${approve[@]}"; then r_destroy=ok; else r_destroy=failed; exit 1; fi ;;
  full)
    rc=0
    if "$tool" apply "${vars[@]}" "${approve[@]}"; then r_apply=ok; else r_apply=failed; rc=1; fi
    if [[ $rc -eq 0 ]]; then check || rc=$?; fi
    if "$tool" destroy "${vars[@]}" "${approve[@]}"; then r_destroy=ok; else r_destroy=failed; rc=1; fi
    exit $rc
    ;;
  *) echo "unknown action: $action" >&2; exit 2 ;;
esac
