#!/usr/bin/env bash
set -Eeuo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-orion-eks-lab}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHAPTER_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ORION_SOURCE="${ORION_SOURCE:-${CHAPTER_DIR}/../00-revisao-e-nivelamento/examples/orion}"

usage() {
  printf 'Uso: %s {preflight|kind-up|kind-validate|kind-cleanup}\n' "$0"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || { printf 'comando ausente: %s\n' "$1" >&2; exit 2; }
}

preflight() {
  require_command kubectl
  require_command docker
  require_command kind
  test -d "${ORION_SOURCE}" || { printf 'fonte da Orion ausente: %s\n' "${ORION_SOURCE}" >&2; exit 2; }
  kubectl create --dry-run=client --validate=false -f "${SCRIPT_DIR}/namespace.yaml" >/dev/null
  kubectl create --dry-run=client --validate=false -f "${SCRIPT_DIR}/orion.yaml" >/dev/null
  kubectl create --dry-run=client --validate=false -f "${SCRIPT_DIR}/orion-pending.yaml" >/dev/null
  printf 'preflight: PASS\n'
}

kind_up() {
  preflight
  if ! kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
    kind create cluster --name "${CLUSTER_NAME}"
  fi
  docker build -t orion-api:lab "${ORION_SOURCE}"
  kind load docker-image orion-api:lab --name "${CLUSTER_NAME}"
  kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"
  kubectl apply -f "${SCRIPT_DIR}/orion.yaml"
  kubectl -n orion rollout status deployment/orion-api --timeout=120s
  kubectl -n orion get pods -o wide
}

kind_validate() {
  require_command kubectl
  kubectl -n orion get deployment,pod,svc,endpointslice -o wide
  kubectl -n orion run dns-check --rm -i --restart=Never --image=busybox:1.36 -- nslookup kubernetes.default.svc.cluster.local
  kubectl -n orion apply -f "${SCRIPT_DIR}/orion-pending.yaml"
  kubectl -n orion wait --for=jsonpath='{.status.conditions[?(@.type=="Available")].status}=False' deployment/orion-pending --timeout=30s || true
  kubectl -n orion describe pod -l app.kubernetes.io/name=orion-pending | sed -n '/Events:/,$p'
  kubectl -n orion delete deployment orion-pending --wait=true
  kubectl -n orion get deployment/orion-api
}

kind_cleanup() {
  kubectl delete namespace orion --wait=true --timeout=120s || true
  kind delete cluster --name "${CLUSTER_NAME}"
}

case "${1:-}" in
  preflight) preflight ;;
  kind-up) kind_up ;;
  kind-validate) kind_validate ;;
  kind-cleanup) kind_cleanup ;;
  *) usage; exit 2 ;;
esac
