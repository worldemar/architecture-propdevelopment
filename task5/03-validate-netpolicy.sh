#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/steps.sh"
. "$DIR/lib/test-functions.sh"

NS="netpol"

step "Checking Kubernetes API connectivity" kubectl cluster-info

step "Check NetworkPolicy provider (Calico or Cilium)" check_np_provider

# Ensure services are ready
for DEP in front-end-app back-end-api-app admin-front-end-app admin-back-end-api-app; do
  step "Ensure deployment/${DEP} is ready" kubectl -n "$NS" rollout status "deployment/${DEP}" --timeout=120s
done

step "Create client pod client-front (role=front-end)" create_client client-front front-end
step "Create client pod client-back (role=back-end-api)" create_client client-back back-end-api
step "Create client pod client-admin-front (role=admin-front-end)" create_client client-admin-front admin-front-end
step "Create client pod client-admin-back (role=admin-back-end-api)" create_client client-admin-back admin-back-end-api

# Allowed pairs (bidirectional) using pod IPs (pre-DNAT evaluation friendly)
step "front-end can reach back-end-api" probe_http_ip client-front back-end-api allow
step "back-end-api can reach front-end" probe_http_ip client-back front-end allow
step "admin-front-end can reach admin-back-end-api" probe_http_ip client-admin-front admin-back-end-api allow
step "admin-back-end-api can reach admin-front-end" probe_http_ip client-admin-back admin-front-end allow

# Forbidden cross-pairs
step "front-end cannot reach admin-back-end-api" probe_http_ip client-front admin-back-end-api deny
step "front-end cannot reach admin-front-end" probe_http_ip client-front admin-front-end deny
step "back-end-api cannot reach admin-front-end" probe_http_ip client-back admin-front-end deny
step "back-end-api cannot reach admin-back-end-api" probe_http_ip client-back admin-back-end-api deny
step "admin-front-end cannot reach back-end-api" probe_http_ip client-admin-front back-end-api deny
step "admin-front-end cannot reach front-end" probe_http_ip client-admin-front front-end deny
step "admin-back-end-api cannot reach back-end-api" probe_http_ip client-admin-back back-end-api deny
step "admin-back-end-api cannot reach front-end" probe_http_ip client-admin-back front-end deny

# service ClusterIP probes
step "front-end can reach back-end-api via Service IP" probe_http_svc_ip client-front back-end-api-app allow
step "admin-front-end can reach admin-back-end-api via Service IP" probe_http_svc_ip client-admin-front admin-back-end-api-app allow
step "front-end cannot reach admin-back-end-api via Service IP" probe_http_svc_ip client-front admin-back-end-api-app deny
step "admin-front-end cannot reach back-end-api via Service IP" probe_http_svc_ip client-admin-front back-end-api-app deny

step "NetworkPolicy validation succeeded" true

# Cleanup client pods
step "Cleanup client test pods" kubectl -n "$NS" delete pod client-front client-back client-admin-front client-admin-back --ignore-not-found


