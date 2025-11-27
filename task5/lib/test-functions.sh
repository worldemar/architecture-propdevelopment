#!/usr/bin/env bash

# Detect NetworkPolicy-capable CNI (Calico/Cilium)
check_np_provider() {
  local has_calico_kube has_calico_sys has_calico_app has_cilium_kube has_cilium_app
  has_calico_kube="$(kubectl -n kube-system get pods -l k8s-app=calico-node -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
  has_calico_sys="$(kubectl -n calico-system get pods -l k8s-app=calico-node -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
  has_calico_app="$(kubectl -n calico-system get pods -l app.kubernetes.io/name=calico-node -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
  has_cilium_kube="$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
  has_cilium_app="$(kubectl -n kube-system get pods -l app.kubernetes.io/name=cilium-agent -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
  if [[ -n "$has_calico_kube$has_calico_sys$has_calico_app" || -n "$has_cilium_kube$has_cilium_app" ]]; then
    return 0
  fi
  echo "No NetworkPolicy provider detected (Calico/Cilium)."
  echo "Enable one of the following and re-run:"
  echo "  minikube start --cni=calico"
  echo "  # or: minikube start --cni=cilium"
  echo "  # existing cluster: kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml"
  return 1
}

# Create a short-lived client pod with specific role label
create_client() {
  local name="$1"
  local role="$2"
  local ns="${NS:-netpol}"
  kubectl -n "$ns" get pod "$name" >/dev/null 2>&1 && return 0
  kubectl -n "$ns" run "$name" \
    --image=alpine:3.19 \
    --labels="role=${role},task=task5" \
    --restart=Never \
    --command -- sh -c "sleep 600" >/dev/null
  kubectl -n "$ns" wait --for=condition=Ready "pod/${name}" --timeout=60s >/dev/null
}

# Probe HTTP by Service DNS name
probe_http() {
  local from_pod="$1"
  local target_svc="$2"
  local expected="$3"
  local ns="${NS:-netpol}"
  if kubectl -n "$ns" exec "$from_pod" -- wget -qO- --timeout=3 "http://${target_svc}" >/dev/null 2>&1; then
    [[ "$expected" == "allow" ]]
  else
    [[ "$expected" == "deny" ]]
  fi
}

# Resolve a Service ClusterIP
svc_ip() {
  local svc="$1"
  local ns="${NS:-netpol}"
  kubectl -n "$ns" get svc "$svc" -o jsonpath='{.spec.clusterIP}'
}

# Probe HTTP by Service ClusterIP (with small retry)
probe_http_svc_ip() {
  local from_pod="$1"
  local svc="$2"
  local expected="$3"
  local ns="${NS:-netpol}"
  local ip
  ip="$(svc_ip "$svc")"
  for i in 1 2 3; do
    if kubectl -n "$ns" exec "$from_pod" -- wget -qO- --timeout=3 "http://${ip}" >/dev/null 2>&1; then
      if [[ "$expected" == "allow" ]]; then return 0; fi
    else
      if [[ "$expected" == "deny" ]]; then return 0; fi
    fi
    sleep 1
  done
  if kubectl -n "$ns" exec "$from_pod" -- wget -qO- --timeout=3 "http://${ip}" >/dev/null 2>&1; then
    [[ "$expected" == "allow" ]]
  else
    [[ "$expected" == "deny" ]]
  fi
}

# Resolve first application pod IP by role (exclude test clients)
pod_ip_by_role() {
  local role="$1"
  local ns="${NS:-netpol}"
  kubectl -n "$ns" get pod -l "role=${role},app" -o jsonpath='{.items[0].status.podIP}'
}

# Probe HTTP by target Pod IP
probe_http_ip() {
  local from_pod="$1"
  local target_role="$2"
  local expected="$3"
  local ns="${NS:-netpol}"
  local ip
  ip="$(pod_ip_by_role "$target_role")"
  if kubectl -n "$ns" exec "$from_pod" -- wget -qO- --timeout=2 http://$ip:80 >/dev/null 2>&1; then
    [[ "$expected" == "allow" ]]
  else
    [[ "$expected" == "deny" ]]
  fi
}
