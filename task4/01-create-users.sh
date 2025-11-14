#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
. "$DIR/lib/steps.sh"

step "Checking Kubernetes API connectivity" kubectl cluster-info

step "Creating namespaces" kubectl apply -f "$DIR/yaml/01-namespaces.yaml"
step "Creating service accounts (users)" kubectl apply -f "$DIR/yaml/01-serviceaccounts.yaml"

echo "All done."


