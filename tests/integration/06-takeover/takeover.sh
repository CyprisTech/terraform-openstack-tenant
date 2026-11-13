#!/usr/bin/env bash
# Stage 06: create objects as by hand (existing/), forget them there, and hand their IDs to
# the stage, which takes them over with import blocks.
#
#   ./takeover.sh prepare     apply existing/, write ids.auto.tfvars.json, empty existing/'s state
#   ../run.sh 06-takeover full
#
# Same environment as run.sh (OS_CLOUD, TOOL, AUTO_APPROVE).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="${TOOL:-tofu}"
cloud="${OS_CLOUD:-tf-module-test}"

case "${1:-}" in
  prepare)
    "$here/../run.sh" 06-takeover/existing apply
    for v in $(compgen -e | grep '^OS_' || true); do unset "$v"; done
    export OS_CLOUD="$cloud"
    cd "$here/existing"
    "$tool" workspace select "$cloud" >/dev/null
    "$tool" output -json ids | python3 -c 'import json, sys; json.dump({"ids": json.load(sys.stdin)}, sys.stdout, indent=2)' >"$here/ids.auto.tfvars.json"
    # Forget the objects: from now on, only the stage manages them.
    "$tool" state list | grep -v '^data\.' | xargs -r -n1 "$tool" state rm >/dev/null
    echo "ids written to $here/ids.auto.tfvars.json; existing/ manages nothing"
    ;;
  *) echo "usage: $0 prepare" >&2; exit 2 ;;
esac
