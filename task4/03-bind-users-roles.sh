#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
. "$DIR/lib/steps.sh"

step "Checking Kubernetes API connectivity" kubectl cluster-info

step "Binding cluster roles" kubectl apply -f "$DIR/yaml/03-clusterrolebindings.yaml"
step "Binding namespace roles" kubectl apply -f "$DIR/yaml/03-rolebindings.yaml"

echo "All done."


