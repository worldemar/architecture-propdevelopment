#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/steps.sh"

step "Checking Kubernetes API connectivity" kubectl cluster-info

step "Delete namespace netpol (includes all services/pods/netpol)" kubectl delete -f "$DIR/yaml/01-namespace.yaml" --ignore-not-found --wait=false

echo "Cleanup initiated (namespace deletion is asynchronous)"


