# Exemplos do kube-prometheus-stack

Este diretório contém exemplos independentes de coleta de métricas com
`ServiceMonitor` e `PodMonitor`.

O roteiro didático completo está em
[`ORCHERST/chapters/07-servicos-de-plataforma-para-operacao/examples/README.md`](../../ORCHERST/chapters/07-servicos-de-plataforma-para-operacao/examples/README.md).

## Uso rápido

Instale o chart com [`monitoring-values.yaml`](monitoring-values.yaml), que
permite ao Prometheus descobrir monitores no namespace `orion`:

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --version 70.4.1 \
  --values monitoring-values.yaml

kubectl apply -f app.yaml
kubectl -n orion rollout status deployment/metrics-demo
kubectl apply -f service-monitor.yaml
```

Para testar a alternativa baseada diretamente em Pods, remova o
`ServiceMonitor` antes:

```bash
kubectl delete -f service-monitor.yaml
kubectl apply -f pod-monitor.yaml
```

Não aplique os dois monitores simultaneamente para a mesma aplicação, pois a
coleta será duplicada.
