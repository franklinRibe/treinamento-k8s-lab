#!/usr/bin/env bash
set -Eeuo pipefail
CLUSTER_NAME="${CLUSTER_NAME:-orion-security-lab}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ORION_SOURCE="${ORION_SOURCE:-${SCRIPT_DIR}/../../00-revisao-e-nivelamento/examples/orion}"
need() { command -v "$1" >/dev/null 2>&1 || { echo "comando ausente: $1" >&2; exit 2; }; }
preflight() {
  need kubectl; need python3
  python3 - "${SCRIPT_DIR}" <<'PY'
import pathlib, sys, yaml
root = pathlib.Path(sys.argv[1])
for path in sorted(root.glob("*.yaml")):
    docs = list(yaml.safe_load_all(path.read_text()))
    if not docs or any(not doc or not doc.get("apiVersion") or not doc.get("kind") for doc in docs):
        raise SystemExit(f"manifesto inválido: {path}")
print("security preflight: PASS")
PY
}
kind_up() {
  need kind; need docker; need kubectl; preflight
  kind create cluster --name "$CLUSTER_NAME"
  docker build -t orion-api:lab "$ORION_SOURCE"
  kind load docker-image orion-api:lab --name "$CLUSTER_NAME"
  kubectl apply -f "$SCRIPT_DIR/orion-security.yaml" -f "$SCRIPT_DIR/orion-default-deny.yaml"
  kubectl -n orion rollout status deployment/orion-api --timeout=120s
}
validate() {
  reader_get="$(kubectl auth can-i get configmaps --as=system:serviceaccount:orion:orion-reader -n orion)"
  reader_list="$(kubectl auth can-i list configmaps --as=system:serviceaccount:orion:orion-reader -n orion)"
  reader_delete="$(kubectl auth can-i delete secrets --as=system:serviceaccount:orion:orion-reader -n orion || true)"
  test "$reader_get" = yes
  test "$reader_list" = yes
  test "$reader_delete" = no
  kubectl apply -f "$SCRIPT_DIR/orion-broken-rbac.yaml"
  # A missing roleRef target is reported as a failed authorization check by
  # kubectl, even though its human-readable result is still "no".
  wrong_rbac_result="$(kubectl auth can-i get configmaps --as=system:serviceaccount:orion:orion-wrong -n orion 2>/dev/null || true)"
  case "$wrong_rbac_result" in
    no*) ;;
    *) echo "resultado RBAC inesperado: $wrong_rbac_result" >&2; return 1 ;;
  esac
  kubectl -n orion get sa,role,rolebinding,secret,deploy,pod,networkpolicy -o wide
  kubectl -n orion get namespace orion --show-labels
  kubectl apply --dry-run=server -f "$SCRIPT_DIR/orion-privileged-example.yaml" >/dev/null
  echo 'privileged example: inspected with server-side dry-run only'
  kubectl -n orion delete rolebinding orion-broken --ignore-not-found
  echo 'security lab: PASS'
}
cleanup() { kind delete cluster --name "$CLUSTER_NAME"; }
case "${1:-}" in
  preflight) preflight;; kind-up) kind_up;; validate) validate;; cleanup) cleanup;;
  *) echo "Uso: $0 {preflight|kind-up|validate|cleanup}"; exit 2;;
esac
