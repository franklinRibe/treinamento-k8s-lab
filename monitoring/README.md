# Duas formas de instalar o Prometheus com Helm

Este laboratório apresenta duas instalações alternativas. Execute apenas uma
delas por vez no mesmo cluster, porque ambas usam recursos de monitoramento e
podem consumir memória e CPU consideráveis.

## Pré-requisitos

- Um cluster Kubernetes acessível pelo `kubectl`;
- `helm` instalado;
- contexto correto selecionado com `kubectl config current-context`.

Execute os comandos a seguir a partir desta pasta:

```bash
cd monitoring
```

Os exemplos foram pensados para laboratório e usam armazenamento efêmero por
padrão. Os dados do Prometheus serão perdidos se o Pod for recriado. Em um
ambiente real, configure um `PersistentVolumeClaim`, uma `StorageClass` e uma
política de retenção adequados.

## Opção 1 — chart `prometheus`

O chart `prometheus` instala o servidor Prometheus de forma mais enxuta. É uma
boa opção quando o objetivo é aprender o servidor, fornecer seus próprios
`scrape_configs` ou controlar cada componente separadamente.

### Instalação

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace \
  --values prometheus/values.yaml
```

O comando é idempotente: na primeira execução cria a release; nas seguintes
atualiza a mesma release. O arquivo [`prometheus/values.yaml`](prometheus/values.yaml)
desabilita componentes auxiliares para deixar explícito o que pertence ao
exemplo principal.

### Verificação e acesso local

```bash
kubectl -n monitoring get pods,svc
kubectl -n monitoring rollout status deployment/prometheus-server --timeout=120s

kubectl -n monitoring port-forward svc/prometheus-server 9090:80
```

Abra <http://localhost:9090> e consulte, por exemplo, a expressão `up`. O
valor `1` indica que o alvo está acessível; `0` indica que o Prometheus
conhece o alvo, mas não conseguiu coletá-lo.

### Limpeza

```bash
helm uninstall prometheus --namespace monitoring
kubectl delete namespace monitoring --ignore-not-found
```

## Opção 2 — chart `kube-prometheus-stack`

O `kube-prometheus-stack` instala uma solução integrada baseada no Prometheus
Operator. Além do Prometheus, o chart pode instalar Grafana, Alertmanager,
`kube-state-metrics`, Node Exporter, regras de alerta e recursos customizados
como `ServiceMonitor` e `PrometheusRule`.

### Instalação

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values kube-prometheus-stack/values.yaml
```

O arquivo [`kube-prometheus-stack/values.yaml`](kube-prometheus-stack/values.yaml)
mantém Grafana habilitado e configura o Prometheus Operator para descobrir
`ServiceMonitor` e `PrometheusRule` independentemente do label gerado pelo
Helm. Isso facilita o uso com aplicações instaladas por outros charts.

### Verificação e acesso local

```bash
kubectl -n monitoring-stack get pods,svc
kubectl -n monitoring-stack get prometheus,servicemonitor,prometheusrule
kubectl -n monitoring-stack rollout status statefulset/prometheus-kube-prometheus-stack-prometheus --timeout=180s

kubectl -n monitoring-stack port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Abra <http://localhost:3000>. O usuário padrão é `admin`; consulte a senha
criada pelo chart com:

```bash
kubectl -n monitoring-stack get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 --decode; echo
```

Para acessar diretamente o Prometheus, use o Service cujo nome termina em
`-prometheus`:

```bash
kubectl -n monitoring-stack get svc | grep prometheus
kubectl -n monitoring-stack port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

### Limpeza

```bash
helm uninstall kube-prometheus-stack --namespace monitoring-stack
kubectl delete namespace monitoring-stack --ignore-not-found
```

## Comparação rápida

| Característica | `prometheus` | `kube-prometheus-stack` |
| --- | --- | --- |
| Escopo | Servidor Prometheus mais simples | Stack integrada de observabilidade |
| Operador | Não | Sim, Prometheus Operator |
| Grafana | Não por padrão neste exemplo | Sim |
| `ServiceMonitor`/`PrometheusRule` | Não é o fluxo principal | Sim |
| Controle e complexidade | Menor | Maior |
| Uso recomendado | Aprendizado do Prometheus ou instalação customizada | Monitoramento completo de clusters Kubernetes |

Não instale os dois exemplos no mesmo namespace ou com a mesma finalidade sem
planejar os alvos e a retenção: é fácil coletar as mesmas métricas duas vezes.

## Diagnóstico inicial

```bash
helm list --all-namespaces
kubectl get events -n monitoring-prometheus --sort-by=.lastTimestamp
kubectl get events -n monitoring-stack --sort-by=.lastTimestamp
kubectl describe pod -n monitoring-stack <nome-do-pod>
```

Se um Pod estiver em `Pending`, verifique capacidade do cluster, requests de
recursos e existência da `StorageClass`. Se estiver em `CrashLoopBackOff`,
leia os logs com `kubectl logs`; se o Prometheus estiver saudável mas `up` for
`0`, investigue o Service, os endpoints, a rede e o caminho de métricas do alvo.
