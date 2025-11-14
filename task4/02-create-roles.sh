#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
. "$DIR/lib/steps.sh"

step "Checking Kubernetes API connectivity" kubectl cluster-info

step "Creating ClusterRoles" kubectl apply -f "$DIR/yaml/02-clusterroles.yaml"
step "Creating namespace Roles" kubectl apply -f "$DIR/yaml/02-roles.yaml"

echo "All done."


