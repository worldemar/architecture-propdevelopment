#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$DIR/lib/steps.sh"

step "Checking Kubernetes API connectivity" kubectl cluster-info

step "Apply default deny all (ingress+egress)" kubectl apply -f "$DIR/yaml/20-default-deny.yaml"
step "Allow DNS egress for all pods" kubectl apply -f "$DIR/yaml/23-allow-dns.yaml"
# Remove legacy combined policies if they exist (renamed in latest iteration)
step "Delete legacy policies if present" bash -lc 'kubectl -n netpol delete networkpolicy allow-front-to-back allow-admin-front-to-admin-back --ignore-not-found'
step "Allow front-end <-> back-end-api on TCP/80" kubectl apply -f "$DIR/yaml/21-non-admin-api-allow.yaml"
step "Allow admin-front-end <-> admin-back-end-api on TCP/80" kubectl apply -f "$DIR/yaml/22-admin-api-allow.yaml"

step "Show effective NetworkPolicies" kubectl -n netpol get networkpolicy

echo "NetworkPolicies applied"


