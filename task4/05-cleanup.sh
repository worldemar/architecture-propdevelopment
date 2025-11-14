#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$DIR/lib/steps.sh"

step "Checking Kubernetes API connectivity" kubectl cluster-info

# Remove test resources created by 04-validate-rbac.sh using label
step "Delete labeled test resources (all namespaces)" kubectl delete all,cm,job,cronjob -l rbac-lab=task4 -A --ignore-not-found

# Delete RBAC bindings and roles (reverse order)
step "Delete RoleBindings" kubectl delete -f "$DIR/yaml/03-rolebindings.yaml" --ignore-not-found
step "Delete ClusterRoleBindings" kubectl delete -f "$DIR/yaml/03-clusterrolebindings.yaml" --ignore-not-found
step "Delete namespace Roles" kubectl delete -f "$DIR/yaml/02-roles.yaml" --ignore-not-found
step "Delete ClusterRoles" kubectl delete -f "$DIR/yaml/02-clusterroles.yaml" --ignore-not-found
step "Delete ServiceAccounts" kubectl delete -f "$DIR/yaml/01-serviceaccounts.yaml" --ignore-not-found
step "Delete Namespaces" kubectl delete -f "$DIR/yaml/01-namespaces.yaml" --ignore-not-found --wait=false

# Ensure namespaces are gone; if stuck in Terminating, remove finalizers
for NS in rbac sales utilities finance data; do
  step "Ensure namespace $NS is deleted (may patch finalizers)" bash -lc '
    for i in {1..30}; do kubectl get ns '"$NS"' >/dev/null 2>&1 || exit 0; sleep 1; done;
    kubectl patch namespace '"$NS"' -p "{\"metadata\":{\"finalizers\":[]}}" --type=merge >/dev/null 2>&1 || true
    for i in {1..15}; do kubectl get ns '"$NS"' >/dev/null 2>&1 || exit 0; sleep 1; done;
    exit 1
  '
done

echo "Cleanup finished"


