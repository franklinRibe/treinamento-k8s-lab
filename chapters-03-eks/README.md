# Laboratório do Capítulo 03

Este laboratório tem dois níveis. O caminho `kind-*` valida localmente o
comportamento Kubernetes sem criar recursos AWS; a execução EKS reproduz as
mesmas evidências em uma conta descartável, com orçamento, região, tags e
permissões aprovados pelo instrutor.

## Contrato de segurança

Não execute criação de cluster EKS por acidente. A execução AWS exige uma
conta de laboratório autorizada, confirmação explícita de custo e um plano de
cleanup. Nunca coloque access keys em Pods e nunca use um cluster compartilhado
para a falha de add-on.

## Caminho local sem custo AWS

A imagem da Orion é construída a partir do código da unidade 00. O script
valida os manifests, cria um cluster kind descartável, testa a Orion saudável,
executa uma resolução DNS e aplica um Deployment propositalmente impossível de
agendar.

```bash
./lab.sh preflight
./lab.sh kind-up
./lab.sh kind-validate
./lab.sh kind-cleanup
```

Na falha de scheduling, não corrija antes de coletar `get`, `describe`,
`spec.nodeName`, requests, nodes e Events. O `nodeSelector` aponta para um
label inexistente; a correção do exercício é remover a restrição ou aplicar um
label somente depois de formular a hipótese.

## Caminho EKS

O instrutor deve adaptar a criação do cluster ao método aprovado (`eksctl`,
Terraform ou AWS CLI) e registrar a configuração efetiva. Depois de configurar
o contexto, use os mesmos manifests e colete:

```bash
aws sts get-caller-identity
aws eks describe-cluster --name "$CLUSTER" --region "$AWS_REGION"
kubectl get nodes -o wide
aws eks list-addons --cluster-name "$CLUSTER" --region "$AWS_REGION"
kubectl -n orion get deploy,pod,svc,endpointslice -o wide
```

Para o cenário de endpoint privado, execute `kubectl get nodes` a partir de
uma rede que não possua a rota autorizada e registre o erro sem alterar o
cluster. Para o cenário de add-on, use somente um namespace/objeto de
laboratório e restaure-o imediatamente; não edite CoreDNS, VPC CNI ou kube-
proxy de um cluster compartilhado.

## Evidência entregue

O aluno entrega um arquivo de execução contendo data, commit, contexto,
versões, comandos, saídas, três hipóteses para cada falha, causa, correção,
teste de recuperação e cleanup. A prova de cleanup inclui a ausência do
namespace, do cluster e dos recursos AWS de suporte, conforme o método de
provisionamento usado.
