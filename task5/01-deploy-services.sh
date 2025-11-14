#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$DIR/lib/steps.sh"

step "Checking Kubernetes API connectivity" kubectl cluster-info

echo "Preloading container image into Minikube (best-effort)"
# This helps when the node cannot pull from Docker Hub directly,
# but the host machine can. Failures are ignored.
(docker pull nginx:1.25-alpine >/dev/null 2>&1 || true; \
 minikube image load nginx:1.25-alpine >/dev/null 2>&1 || true; \
 minikube cache add nginx:1.25-alpine >/dev/null 2>&1 || true) || true

step "Create namespace netpol" kubectl apply -f "$DIR/yaml/01-namespace.yaml"
step "Deploy four Nginx services (front/back + admin pair)" kubectl apply -f "$DIR/yaml/10-nginx-services.yaml"

for DEP in front-end-app back-end-api-app admin-front-end-app admin-back-end-api-app; do
  step "Wait rollout of deployment/${DEP}" kubectl -n netpol rollout status "deployment/${DEP}" --timeout=120s
done

step "List services in netpol" kubectl -n netpol get svc -o wide

echo "Services deployed"


