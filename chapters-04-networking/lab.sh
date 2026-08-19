#!/usr/bin/env bash
set -Eeuo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-orion-networking-lab}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ORION_SOURCE="${ORION_SOURCE:-${SCRIPT_DIR}/../../00-revisao-e-nivelamento/examples/orion}"

usage() { printf 'Uso: %s {preflight|kind-up|kind-validate|kind-cleanup|eks-preview|eks-apply}\n' "$0"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "comando ausente: $1" >&2; exit 2; }; }

preflight() {
  need python3
  python3 - "${SCRIPT_DIR}" <<'PY'
import pathlib
import sys

import yaml

root = pathlib.Path(sys.argv[1])
files = [
    "orion-workload.yaml",
    "orion-clusterip.yaml",
    "orion-nodeport.yaml",
    "orion-loadbalancer.yaml",
    "orion-ingress-alb.yaml",
    "service-broken-selector.yaml",
]
for name in files:
    path = root / name
    documents = list(yaml.safe_load_all(path.read_text()))
    if not documents or any(not doc or not doc.get("apiVersion") or not doc.get("kind") for doc in documents):
        raise SystemExit(f"manifesto inválido: {path}")
print(f"{len(files)} manifestos YAML parseados")
PY
  echo 'preflight: PASS'
}

kind_up() {
  need kind; need docker
  preflight
  kind create cluster --name "${CLUSTER_NAME}"
  docker build -t orion-api:lab "${ORION_SOURCE}"
  kind load docker-image orion-api:lab --name "${CLUSTER_NAME}"
  kubectl apply -f "${SCRIPT_DIR}/orion-workload.yaml"
  kubectl apply -f "${SCRIPT_DIR}/orion-clusterip.yaml" -f "${SCRIPT_DIR}/orion-nodeport.yaml"
  kubectl -n orion rollout status deployment/orion-api --timeout=120s
}

kind_validate() {
  kubectl -n orion get deploy,pod,svc,endpointslice -o wide
  kubectl -n orion run dns-check --rm -i --restart=Never --image=busybox:1.36 -- nslookup orion-clusterip.orion.svc.cluster.local
  kubectl -n orion apply -f "${SCRIPT_DIR}/service-broken-selector.yaml"
  test -z "$(kubectl -n orion get endpointslice -l kubernetes.io/service-name=orion-broken -o jsonpath='{range .items[*].endpoints[*].addresses[*]}{.}{"\n"}{end}')"
  kubectl -n orion describe svc orion-broken | sed -n '/Events:/,$p' || true
  kubectl -n orion delete service orion-broken --wait=true
}

kind_cleanup() {
  kubectl delete namespace orion --wait=true --timeout=120s || true
  kind delete cluster --name "${CLUSTER_NAME}"
}

eks_preview() {
  preflight
  echo 'EKS preview: nenhum recurso será criado.'
  echo "kubectl apply -f ${SCRIPT_DIR}/orion-loadbalancer.yaml"
  echo "kubectl apply -f ${SCRIPT_DIR}/orion-ingress-alb.yaml"
  echo 'Depois, observar Service/Ingress, Events, targets e health checks.'
}

eks_apply() {
  need aws
  : "${AWS_REGION:?defina AWS_REGION}"
  : "${CLUSTER:?defina CLUSTER}"
  echo 'ATENÇÃO: este comando cria/atualiza recursos AWS e pode gerar custo.' >&2
  aws sts get-caller-identity --region "$AWS_REGION"
  kubectl apply -f "${SCRIPT_DIR}/orion-loadbalancer.yaml"
  kubectl apply -f "${SCRIPT_DIR}/orion-ingress-alb.yaml"
  kubectl -n orion get svc orion-nlb -w
}

case "${1:-}" in
  preflight) preflight;; kind-up) kind_up;; kind-validate) kind_validate;; kind-cleanup) kind_cleanup;;
  eks-preview) eks_preview;; eks-apply) eks_apply;; *) usage; exit 2;;
esac
