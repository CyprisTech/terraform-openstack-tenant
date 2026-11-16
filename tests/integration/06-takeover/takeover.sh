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
    # At scale, the model and the import list are generated from the API rather than written by
    # hand: here, the rules of one group, keyed by protocol and port (docs/takeover.md, At scale).
    group=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["ids"]["web_group"])' "$here/ids.auto.tfvars.json")
    openstack security group rule list "$group" --ingress -f json | python3 -c '
import json, sys
rules = {}
for r in json.load(sys.stdin):
    if r["Ethertype"] != "IPv4":
        continue
    port = int(r["Port Range"].split(":")[0])
    rules["%s-%d" % (r["IP Protocol"], port)] = {
        "id": r["ID"], "protocol": r["IP Protocol"], "port": port, "remote_ip_prefix": r["IP Range"]}
json.dump({"web_rules": rules}, sys.stdout, indent=2)' >"$here/web.auto.tfvars.json"
    # Forget the objects: from now on, only the stage manages them.
    "$tool" state list | grep -v '^data\.' | while IFS= read -r address; do "$tool" state rm "$address" >/dev/null; done
    echo "ids written to $here/ids.auto.tfvars.json and web.auto.tfvars.json; existing/ manages nothing"
    ;;
  *) echo "usage: $0 prepare" >&2; exit 2 ;;
esac
