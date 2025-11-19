#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib/steps.sh"
. "$DIR/lib/test-functions.sh"

PRIV="system:serviceaccount:rbac:priv-admin"
OPS="system:serviceaccount:rbac:ops"
VIEWER="system:serviceaccount:rbac:viewer"
SALES_DEV="system:serviceaccount:sales:sales-dev"

NS_SALES="sales"
NS_UTIL="utilities"
NS_FIN="finance"
NS_DATA="data"
NAMESPACES=("$NS_SALES" "$NS_UTIL" "$NS_FIN" "$NS_DATA")
DEV_MAP=("sales:sales-dev" "utilities:utilities-dev" "finance:finance-dev" "data:data-dev")

step "Checking Kubernetes API connectivity" kubectl cluster-info

# Cleanup any leftovers from previous runs
step "Cleanup previous test resources (configmap)" kubectl -n "$NS_SALES" delete configmap rbac-test-cm --ignore-not-found
step "Cleanup previous test resources (deployment)" kubectl -n "$NS_SALES" delete deployment rbac-test-deploy --ignore-not-found
step "Cleanup previous test resources (job)" kubectl -n "$NS_SALES" delete job rbac-test-job --ignore-not-found
step "Cleanup previous test resources (cronjob)" kubectl -n "$NS_SALES" delete cronjob rbac-test-cron --ignore-not-found

# 0) Structural checks: RoleBinding subjects match expected service accounts
for entry in "${DEV_MAP[@]}"; do
  ns="${entry%%:*}"
  sa="${entry##*:}"
  step "RoleBinding ns-developer-binding in ${ns} bound to ServiceAccount ${sa}" assert_rb_subject_matches "$ns" "$sa"
done

# 1) priv-admin: can read secrets in any namespace (and in rbac)
for ns in "${NAMESPACES[@]}"; do
  step "priv-admin can get secrets in ${ns}" assert_can "$PRIV" "$ns" get secrets
done
step "priv-admin can get secrets in rbac" assert_can "$PRIV" "rbac" get secrets
step "priv-admin can get/list/watch namespaces (cluster-scope)" verbs_can_cluster "$PRIV" namespaces "get list watch"

# 2) ops: can manage workloads cluster-wide (deployments, daemonsets, statefulsets, replicasets, jobs, cronjobs, services, ingresses), but cannot read secrets
for ns in "${NAMESPACES[@]}"; do
  verbs_can "$OPS" "$ns" deployments "get list watch create update patch delete"
  verbs_can "$OPS" "$ns" daemonsets "get list watch create update patch delete"
  verbs_can "$OPS" "$ns" statefulsets "get list watch create update patch delete"
  verbs_can "$OPS" "$ns" replicasets "get list watch create update patch delete"
  verbs_can "$OPS" "$ns" jobs "get list watch create update patch delete"
  verbs_can "$OPS" "$ns" cronjobs "get list watch create update patch delete"
  verbs_can "$OPS" "$ns" services "get list watch create update patch delete"
  verbs_can "$OPS" "$ns" ingresses "get list watch create update patch delete"
  verbs_can "$OPS" "$ns" configmaps "get list watch create update patch delete"
  verbs_cannot "$OPS" "$ns" secrets "get list watch"
done

# one real deploy to verify beyond can-i
step "ops create deployment in $NS_SALES" kubectl --as="$OPS" -n "$NS_SALES" create deployment rbac-test-deploy --image=nginx --replicas=1
step "ops label deployment" kubectl -n "$NS_SALES" label deployment rbac-test-deploy rbac-lab=task4 --overwrite
step "ops create job in $NS_SALES" create_job_as "$OPS" "$NS_SALES" "rbac-test-job"
step "ops create cronjob in $NS_SALES" create_cronjob_as "$OPS" "$NS_SALES" "rbac-test-cron"
step "ops patch deployment annotation" kubectl --as="$OPS" -n "$NS_SALES" patch deployment rbac-test-deploy -p '{"metadata":{"annotations":{"rbac-test":"1"}}}'
step "ops update deployment (replace replicas=2)" bash -lc 'kubectl -n '"$NS_SALES"' get deploy rbac-test-deploy -o yaml | sed "s/replicas: 1/replicas: 2/" | kubectl --as='"$OPS"' -n '"$NS_SALES"' replace -f -'

# 3) viewer: read-only across namespaces
for ns in "${NAMESPACES[@]}"; do
  verbs_can "$VIEWER" "$ns" pods "get list watch"
  verbs_can "$VIEWER" "$ns" configmaps "get list watch"
  verbs_can "$VIEWER" "$ns" deployments "get list watch"
  verbs_cannot "$VIEWER" "$ns" secrets "get list watch"
  verbs_cannot "$VIEWER" "$ns" configmaps "create update patch delete"
  verbs_cannot "$VIEWER" "$ns" deployments "create update patch delete"
  verbs_cannot "$VIEWER" "$ns" jobs "create update patch delete"
  verbs_cannot "$VIEWER" "$ns" cronjobs "create update patch delete"
done
step "readonly-custom can get/list/watch namespaces (cluster-scope)" verbs_can_cluster "$VIEWER" namespaces "get list watch"

# 4) namespace dev SAs: positive in own ns, negative in others, no secrets
for entry in "${DEV_MAP[@]}"; do
  ns="${entry%%:*}"
  sa="${entry##*:}"
  principal="$(sa_principal "$ns" "$sa")"
  verbs_can "$principal" "$ns" configmaps "get list watch create update patch delete"
  verbs_can "$principal" "$ns" deployments "get list watch create update patch delete"
  verbs_can "$principal" "$ns" daemonsets "get list watch create update patch delete"
  verbs_can "$principal" "$ns" statefulsets "get list watch create update patch delete"
  verbs_can "$principal" "$ns" replicasets "get list watch create update patch delete"
  verbs_can "$principal" "$ns" jobs "get list watch create update patch delete"
  verbs_can "$principal" "$ns" cronjobs "get list watch create update patch delete"
  verbs_can "$principal" "$ns" services "get list watch create update patch delete"
  verbs_can "$principal" "$ns" ingresses "get list watch create update patch delete"
  step "${sa} cannot get secrets in ${ns}" assert_cannot "$principal" "$ns" get secrets
  step "${sa} cannot list/watch secrets in ${ns}" verbs_cannot "$principal" "$ns" secrets "list watch"
  for other in "${NAMESPACES[@]}"; do
    if [[ "$other" != "$ns" ]]; then
      verbs_cannot "$principal" "$other" configmaps "get list watch create update patch delete"
      verbs_cannot "$principal" "$other" deployments "get list watch create update patch delete"
      verbs_cannot "$principal" "$other" daemonsets "get list watch create update patch delete"
      verbs_cannot "$principal" "$other" statefulsets "get list watch create update patch delete"
      verbs_cannot "$principal" "$other" replicasets "get list watch create update patch delete"
      verbs_cannot "$principal" "$other" jobs "get list watch create update patch delete"
      verbs_cannot "$principal" "$other" cronjobs "get list watch create update patch delete"
      verbs_cannot "$principal" "$other" services "get list watch create update patch delete"
      verbs_cannot "$principal" "$other" ingresses "get list watch create update patch delete"
    fi
  done
done

# one real create for sales-dev to verify beyond can-i
step "sales-dev create configmap in $NS_SALES" kubectl --as="$SALES_DEV" -n "$NS_SALES" create configmap rbac-test-cm --from-literal=k=v
step "sales-dev label configmap" kubectl -n "$NS_SALES" label configmap rbac-test-cm rbac-lab=task4 --overwrite
step "sales-dev create job in $NS_SALES" create_job_as "$SALES_DEV" "$NS_SALES" "rbac-test-job"
step "sales-dev create cronjob in $NS_SALES" create_cronjob_as "$SALES_DEV" "$NS_SALES" "rbac-test-cron"
step "sales-dev patch configmap" kubectl --as="$SALES_DEV" -n "$NS_SALES" patch configmap rbac-test-cm -p '{"metadata":{"annotations":{"rbac-test":"1"}}}'
step "sales-dev update configmap (replace data)" bash -lc 'kubectl -n '"$NS_SALES"' get cm rbac-test-cm -o yaml | sed "s/k: v/k: v2/" | kubectl --as='"$SALES_DEV"' -n '"$NS_SALES"' replace -f -'

# Cleanup created resources
step "Cleanup test deployment" kubectl -n "$NS_SALES" delete deployment rbac-test-deploy --ignore-not-found
step "Cleanup test configmap" kubectl -n "$NS_SALES" delete configmap rbac-test-cm --ignore-not-found
step "Cleanup test job" kubectl -n "$NS_SALES" delete job rbac-test-job --ignore-not-found
step "Cleanup test cronjob" kubectl -n "$NS_SALES" delete cronjob rbac-test-cron --ignore-not-found

echo "RBAC validation finished"
