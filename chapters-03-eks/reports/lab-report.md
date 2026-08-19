Lab Validation: PASS

# Lab Validation

## Fonte sob validação

- Branch: `agent/ch03-pipeline`
- Subject executado: `44cb956065bd5ae7b29f96d0bb1a4ff44c961704`
- Data: 2026-08-18
- Árvore inicial: limpa antes da execução
- Isolamento: cluster kind descartável `orion-eks-lab`

## Ambiente

- kind: `v0.31.0`
- Node image/Kubernetes server: `kindest/node:v1.35.0`
- kubectl client: `v1.30.14`
- Docker client: `29.7.2`
- AWS/EKS: não executado; nenhum recurso ou custo AWS foi criado.

## Resultados

### Preflight e baseline — PASS

`examples/lab.sh preflight` passou. O script validou os três manifests com
`kubectl create --dry-run=client --validate=false`.

`kind-up` criou o cluster descartável, construiu `orion-api:lab`, carregou a
imagem no node e concluiu o rollout com dois Pods `1/1 Running` e `Ready`.

### DNS e estado da plataforma — PASS

`kind-validate` confirmou Deployment, Pods, Service e EndpointSlice. O teste
funcional resolveu `kubernetes.default.svc.cluster.local` para `10.96.0.1`.

### Falha de scheduling — PASS

`orion-pending.yaml` foi aplicado com `nodeSelector` deliberadamente
inexistente. O scheduler registrou:

```text
0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector
```

O Deployment defeituoso foi removido depois da coleta. A Orion saudável
permaneceu `2/2` disponível.

### Cleanup — PASS

O namespace `orion` e o cluster `orion-eks-lab` foram removidos. Nenhum recurso
AWS foi criado; portanto não há cleanup AWS pendente.

## Limitações

- A execução kind valida o contrato Kubernetes, não a topologia VPC, endpoint,
  add-ons EKS, IAM ou custo AWS.
- O caminho EKS permanece documentado em `examples/README.md` e requer conta
  descartável e autorização explícita antes de ser executado.
- A imagem kind usa Kubernetes 1.35.0 e o cliente 1.30.14; a diferença foi
  registrada e não altera os manifests básicos exercitados.
