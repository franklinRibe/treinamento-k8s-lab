# Laboratório do capítulo 03 — EKS operável

Este roteiro exercita topologia, endpoint, compute, nodes, add-ons, evidência
operacional e cleanup. Exige uma conta AWS descartável e não deve ser
executado em cluster compartilhado.

## Preparação

Defina variáveis sem gravar credenciais em arquivos versionados:

```bash
export AWS_PROFILE=perfil-do-lab
export AWS_REGION=sa-east-1
export CLUSTER=treinamento-k8s-03
aws sts get-caller-identity
aws configure list
```

Confirme orçamento, tags, permissões, subnets e política de acesso do
endpoint. O livro não fixa uma ferramenta de provisionamento: use o método
aprovado pelo instrutor (`eksctl`, Terraform, CloudFormation ou equivalente).

## Parte A — baseline

Crie o cluster, configure o contexto, aplique a Orion e registre endpoint,
versão, modo de acesso, nodes e add-ons:

```bash
aws eks describe-cluster --name "$CLUSTER" --region "$AWS_REGION"
aws eks list-nodegroups --cluster-name "$CLUSTER" --region "$AWS_REGION"
aws eks list-addons --cluster-name "$CLUSTER" --region "$AWS_REGION"
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

## Parte B — falha de acesso

De uma rede sem rota autorizada para um endpoint privado, execute `kubectl get
nodes`. Registre o erro antes de mudar a configuração. Diferencie contexto,
DNS, rota, security group e política do endpoint de indisponibilidade do
control plane.

## Parte C — falha de capacidade

Aplique uma variante da Orion cujo request não caiba na capacidade disponível.
Colete Pod, `spec.nodeName`, requests, allocatable, taints e Events:

```bash
kubectl -n orion get pod -o wide
kubectl -n orion describe pod "$POD"
kubectl get nodes -o wide
kubectl describe node "$NODE"
```

Corrija com justificativa e prove que a Orion ficou saudável sem ocultar a
causa original.

## Parte D — add-on

Escolha um add-on aplicável e autorizado. Não altere componentes de sistema de
cluster compartilhado. Relacione estas evidências:

```bash
aws eks list-addons --cluster-name "$CLUSTER" --region "$AWS_REGION"
kubectl -n kube-system get deploy,ds,pod -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

O relatório deve conter sintoma, três hipóteses, comandos, causa, correção,
teste de recuperação e prevenção.

## Parte E — cleanup

Remova a aplicação e os recursos do laboratório; depois remova o cluster
conforme a ferramenta usada. Confirme node groups, interfaces, volumes, NAT,
load balancers, endereços e grupos de logs. Registre qualquer recurso que
exigiu remoção separada.

Use [`reports/lab-report.md`](reports/lab-report.md) como checklist. Nunca
inclua tokens, chaves ou saídas com segredos no commit.

