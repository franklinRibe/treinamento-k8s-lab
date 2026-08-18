# treinamento-k8s-lab

Laboratórios práticos do treinamento de Kubernetes. Este repositório é
independente do livro: os exemplos podem ser executados, alterados e
descartados sem modificar o repositório editorial.

## Trilhas

- `chapters-00-examples/`: fundamentos, imagem local da Orion, Deployment,
  Service, probes e diagnóstico de falhas.
- `chapters-01-examples/`: modelo mental e API de referência.
- `chapters-02-examples/`: ciclo de vida de Pods, Jobs, CRD, RBAC, quotas e
  limites.
- `chapters-03-eks/`: roteiro operacional do capítulo de EKS, com baseline,
  falhas de acesso, capacidade, add-ons e cleanup.

Os três primeiros diretórios foram copiados dos exemplos executáveis do livro.
O capítulo 03 é separado porque cria recursos AWS e exige conta, região,
orçamento e permissões aprovados.

## Pré-requisitos e instalação

### Obrigatórios para a trilha local

Instale todos estes itens antes de executar os labs locais:

- Docker Engine, ou outro runtime Docker compatível;
- `kubectl`;
- Kind;
- `curl`;
- Git.

Links oficiais:

- [Docker Engine](https://docs.docker.com/engine/install/)
- [kubectl — instalar ferramentas Kubernetes](https://kubernetes.io/docs/tasks/tools/)
- [kubectl no Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [Kind — Quick Start e instalação](https://kind.sigs.k8s.io/docs/user/quick-start/)

### Adicionais obrigatórios para a trilha EKS

Além dos itens da trilha local, o laboratório EKS exige:

- AWS CLI configurada;
- uma ferramenta de criação aprovada pelo instrutor, como `eksctl` ou IaC do
  curso;
- conta AWS descartável, região, orçamento, tags e permissões definidos.

Links oficiais:

- [AWS CLI — instalação e atualização](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [AWS CLI — documentação](https://docs.aws.amazon.com/cli/)
- [eksctl — documentação](https://eksctl.io/)

### Opcionais

Estas ferramentas não são necessárias para executar os manifests:

- [Docker Desktop](https://docs.docker.com/desktop/): alternativa integrada
  ao Docker Engine; não é pré-requisito adicional;
- [Krew — instalação](https://krew.sigs.k8s.io/docs/user-guide/setup/install/):
  gerenciador de plugins do `kubectl`;
- [`kubectx` e `kubens` (`ctx` e `ns`)](https://github.com/ahmetb/kubectx):
  agilizam a troca de contexto e namespace.

Não coloque chaves AWS em manifests, imagens ou repositórios. Prefira perfis,
`AWS_PROFILE` e credenciais temporárias.

Valide a instalação:

```bash
docker version
kubectl version --client
kind version
curl --version
git --version
aws --version                       # somente na trilha EKS
aws sts get-caller-identity         # somente na trilha EKS
```

### Opcionais: Krew, ctx e ns

O Krew é o gerenciador de plugins do `kubectl`. Depois de instalá-lo, os
comandos `kubectl krew`, `kubectl ctx` e `kubectl ns` ficam disponíveis quando
os plugins correspondentes forem instalados:

```bash
kubectl krew update
kubectl krew install ctx ns
kubectl ctx
kubectl ns
```

Também é possível instalar `kubectx` e `kubens` diretamente pelo projeto
oficial, sem Krew. Nesse caso, os comandos são `kubectx`/`kubens`; `ctx`/`ns`
correspondem aos nomes dos plugins instalados via Krew.

## Início rápido: Kind

```bash
kind create cluster --name treinamento-k8s
kubectl cluster-info --context kind-treinamento-k8s
kubectl get nodes
```

Execute a trilha introdutória:

```bash
cd chapters-00-examples
docker build -t orion-api:lab orion
kind load docker-image orion-api:lab --name treinamento-k8s
kubectl apply --dry-run=server -f namespace.yaml
kubectl apply -f namespace.yaml
kubectl apply -f orion.yaml
kubectl -n orion rollout status deployment/orion-api --timeout=120s
kubectl -n orion get pods,svc,endpointslice
```

O roteiro completo, incluindo exercício defeituoso e cleanup, está em
[`chapters-00-examples/README.md`](chapters-00-examples/README.md).

Ao terminar:

```bash
kubectl delete namespace orion --wait=true --timeout=120s
kind delete cluster --name treinamento-k8s
```

## Evidências e segurança

Para cada exercício, registre data, contexto, versões, comandos, saídas,
hipótese, evidência, correção e resultado. Não trate apenas `kubectl apply` ou
o status `ACTIVE` de um recurso como prova de funcionamento.

O laboratório EKS pode gerar cobrança por cluster, EC2, NAT Gateway, volumes,
logs, endereços e transferência. Confirme o cleanup e revise a conta AWS.

## Estrutura

```text
.
├── README.md
├── chapters-00-examples/
├── chapters-01-examples/
├── chapters-02-examples/
└── chapters-03-eks/
    ├── README.md
    └── reports/lab-report.md
```
