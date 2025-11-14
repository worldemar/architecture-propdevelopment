# Helper for 'can-i' that works across kubectl versions
check_if_i_can() {
  # Usage: can_i SUBJECT NAMESPACE VERB RESOURCE [EXTRA_ARGS...]
  local subject="$1"; shift
  local namespace="$1"; shift
  local verb="$1"; shift
  local resource="$1"; shift
  # try --quiet (newer kubectl), fallback to grep yes (older)
  kubectl auth can-i --as="$subject" -n "$namespace" "$verb" "$resource" "$@" --quiet 2>/dev/null \
    || kubectl auth can-i --as="$subject" -n "$namespace" "$verb" "$resource" "$@" | grep -q '^yes$'
}

assert_can() {
  check_if_i_can "$@"
}

assert_cannot() {
  if check_if_i_can "$@"; then
    return 1
  else
    return 0
  fi
}

sa_principal() {
  local ns="$1"
  local sa="$2"
  echo "system:serviceaccount:${ns}:${sa}"
}

get_ns_dev_binding_subject() {
  # prints: KIND:NAME:NAMESPACE or empty on failure
  local ns="$1"
  kubectl -n "$ns" get rolebinding ns-developer-binding -o jsonpath='{.subjects[0].kind}:{.subjects[0].name}:{.subjects[0].namespace}' 2>/dev/null || true
}

assert_rb_subject_matches() {
  # args: namespace expected_sa_name
  local ns="$1"
  local expect_sa="$2"
  local got
  got="$(get_ns_dev_binding_subject "$ns")"
  [[ "$got" == "ServiceAccount:${expect_sa}:${ns}" ]]
}

# Helpers to create and cleanup batch resources with manifests
create_job_as() {
  # args: subject ns name
  local subject="$1"; shift
  local ns="$1"; shift
  local name="$1"; shift
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${name}
  labels:
    rbac-lab: "task4"
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: ${name}
          image: busybox
          command: ["sh","-c","echo hello; sleep 1"]
EOF
  kubectl --as="$subject" -n "$ns" apply -f "$tmp"
  rm -f "$tmp"
}

create_cronjob_as() {
  # args: subject ns name
  local subject="$1"; shift
  local ns="$1"; shift
  local name="$1"; shift
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${name}
  labels:
    rbac-lab: "task4"
spec:
  schedule: "* * * * *"
  successfulJobsHistoryLimit: 0
  failedJobsHistoryLimit: 0
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: ${name}
              image: busybox
              command: ["sh","-c","date; echo cron"]
EOF
  kubectl --as="$subject" -n "$ns" apply -f "$tmp"
  rm -f "$tmp"
}

# Helpers to check sets of verbs for a given resource
verbs_can() {
  # args: subject ns resource "verb1 verb2 ..."
  local subject="$1"; shift
  local ns="$1"; shift
  local resource="$1"; shift
  local verbs_str="$*"
  for v in $verbs_str; do
    step "${subject} can-i ${v} ${resource} in ${ns}" assert_can "$subject" "$ns" "$v" "$resource"
  done
}

verbs_cannot() {
  # args: subject ns resource "verb1 verb2 ..."
  local subject="$1"; shift
  local ns="$1"; shift
  local resource="$1"; shift
  local verbs_str="$*"
  for v in $verbs_str; do
    step "${subject} cannot ${v} ${resource} in ${ns}" assert_cannot "$subject" "$ns" "$v" "$resource"
  done
}

# Cluster-scoped checks (no namespace flag)
check_if_i_can_cluster() {
  local subject="$1"; shift
  local verb="$1"; shift
  local resource="$1"; shift
  kubectl auth can-i --as="$subject" "$verb" "$resource" "$@" --quiet 2>/dev/null \
    || kubectl auth can-i --as="$subject" "$verb" "$resource" "$@" | grep -q '^yes$'
}

verbs_can_cluster() {
  local subject="$1"; shift
  local resource="$1"; shift
  local verbs_str="$*"
  for v in $verbs_str; do
    step "${subject} can-i ${v} ${resource} (cluster)" check_if_i_can_cluster "$subject" "$v" "$resource"
  done
}
