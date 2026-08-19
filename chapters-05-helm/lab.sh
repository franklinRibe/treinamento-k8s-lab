#!/usr/bin/env bash
set -Eeuo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-orion-helm-lab}"
RELEASE="${RELEASE:-orion}"
NAMESPACE="${NAMESPACE:-orion}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHART="${SCRIPT_DIR}/orion-chart"
CHART_V2="${SCRIPT_DIR}/orion-chart-v2"
ORION_SOURCE="${ORION_SOURCE:-${SCRIPT_DIR}/../../00-revisao-e-nivelamento/examples/orion}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "comando ausente: $1" >&2; exit 2; }; }
preflight() {
  need helm; need python3
  helm lint "$CHART"
  helm template "$RELEASE" "$CHART" -n "$NAMESPACE" -f "$CHART/values-dev.yaml" >/dev/null
  python3 - "$CHART" <<'PY'
import pathlib, sys, yaml
root = pathlib.Path(sys.argv[1])
for path in [root / "Chart.yaml", root / "values.yaml", root / "values-dev.yaml"]:
    data = yaml.safe_load(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit(f"YAML inválido: {path}")
print("chart preflight: PASS")
PY
}

kind_up() {
  need kind; need docker; need helm; need kubectl
  preflight
  kind create cluster --name "$CLUSTER_NAME"
  docker build -t orion-api:lab "$ORION_SOURCE"
  kind load docker-image orion-api:lab --name "$CLUSTER_NAME"
  helm install "$RELEASE" "$CHART" -n "$NAMESPACE" --create-namespace \
    -f "$CHART/values-dev.yaml" --wait --timeout 120s
}

validate() {
  helm test "$RELEASE" -n "$NAMESPACE" --logs
  helm history "$RELEASE" -n "$NAMESPACE"
  helm upgrade "$RELEASE" "$CHART_V2" -n "$NAMESPACE" \
    -f "$CHART/values-dev.yaml" --set app.message="orion-v2" \
    --wait --timeout 120s
  kubectl -n "$NAMESPACE" rollout status deployment/orion-orion --timeout=120s
  helm history "$RELEASE" -n "$NAMESPACE" | grep -q '2.*deployed'
  helm upgrade "$RELEASE" "$CHART" -n "$NAMESPACE" \
    -f "$CHART/values-dev.yaml" --set app.message="orion-v1-downgraded" \
    --wait --timeout 120s
  helm history "$RELEASE" -n "$NAMESPACE" | grep -q '3.*deployed'
  helm rollback "$RELEASE" 1 -n "$NAMESPACE" --wait --timeout 120s
  helm history "$RELEASE" -n "$NAMESPACE" | grep -q '4.*deployed'
  kubectl -n "$NAMESPACE" get deploy,pod,svc,endpointslice -o wide
  echo 'helm lab: PASS'
}

cleanup() { kind delete cluster --name "$CLUSTER_NAME"; }

case "${1:-}" in
  preflight) preflight;; kind-up) kind_up;; validate) validate;; cleanup) cleanup;;
  *) echo "Uso: $0 {preflight|kind-up|validate|cleanup}"; exit 2;;
esac
