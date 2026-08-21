# AWS Load Balancer Controller com IRSA

Este exemplo instala o AWS Load Balancer Controller no Amazon EKS usando
**IAM Roles for Service Accounts (IRSA)**, em vez de EKS Pod Identity.

O fluxo de credenciais é:

```text
Pod do controller
  -> ServiceAccount aws-load-balancer-controller
  -> token OIDC projetado pelo Kubernetes
  -> AWS STS: AssumeRoleWithWebIdentity
  -> IAM role do controller
  -> APIs do Elastic Load Balancing, EC2 e EKS
```

Este diretório é uma alternativa ao exemplo `../alb-example`, que usa Pod
Identity. Não instale os dois controllers no mesmo cluster usando a mesma
ServiceAccount ao mesmo tempo.

## Pré-requisitos

Tenha disponível:

- um cluster EKS em execução;
- credenciais AWS com permissão para criar OIDC provider, policy, role e
  ServiceAccount;
- `aws` CLI versão 2.12.3 ou posterior;
- `eksctl`, `kubectl` e `helm` instalados;
- o contexto do `kubectl` apontando para o cluster correto;
- subnets e security groups configurados para o cluster.

Confira o ambiente:

```bash
kubectl config current-context
aws sts get-caller-identity
aws eks describe-cluster \
  --name SEU-CLUSTER \
  --query 'cluster.status' \
  --output text
```

Substitua `SEU-CLUSTER`, `REGIAO`, `ACCOUNT_ID` e `vpc-XXXXXXXX` nos
comandos. A instalação abaixo usa o AWS Load Balancer Controller `v2.14.1`
com chart Helm `1.14.0`.

## 1. Garantir o OIDC provider do cluster

IRSA usa o issuer OIDC do cluster para que o AWS Security Token Service (STS)
valide o token da ServiceAccount. Cada cluster EKS precisa de um OIDC
provider IAM correspondente.

```bash
eksctl utils associate-iam-oidc-provider \
  --region us-east-2 \
  --cluster orion \
  --approve
```

Confirme o issuer usado pelo cluster:

```bash
aws eks describe-cluster \
  --name orion \
  --query 'cluster.identity.oidc.issuer' \
  --output text
```

O valor retornado será parecido com:

```text
https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE123456789
```

Na trust policy abaixo, `OIDC_PROVIDER` significa o mesmo valor sem o
prefixo `https://`, por exemplo
`oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE123456789`.

## 2. Criar a policy IAM do controller

Baixe a policy correspondente à versão do controller:

```bash
curl -O \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json
```

Crie a policy:

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

Se ela já existir, reutilize este ARN:

```text
arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy
```

Em AWS GovCloud, AWS China ou outra partição especial, use a policy específica
da partição.

## 3. Criar a role IAM confiando no OIDC provider

Crie `trust-policy.json`. Substitua `ACCOUNT_ID` e todas as ocorrências de
`OIDC_PROVIDER` pelo account ID e issuer OIDC do seu cluster:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "OIDC_PROVIDER:aud": "sts.amazonaws.com",
          "OIDC_PROVIDER:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
```

As condições `aud` e `sub` limitam a role à ServiceAccount específica. Não
remova essas condições em um ambiente real.

Crie a role e anexe a policy:

```bash
aws iam create-role \
  --role-name AmazonEKSLoadBalancerControllerRoleIRSA \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name AmazonEKSLoadBalancerControllerRoleIRSA \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy
```

Valide a configuração:

```bash
aws iam get-role \
  --role-name AmazonEKSLoadBalancerControllerRoleIRSA \
  --query 'Role.AssumeRolePolicyDocument'

aws iam list-attached-role-policies \
  --role-name AmazonEKSLoadBalancerControllerRoleIRSA
```

## 4. Criar a ServiceAccount anotada

A ServiceAccount precisa existir antes da instalação do chart, pois o chart
será configurado com `serviceAccount.create=false`.

```bash
kubectl create serviceaccount aws-load-balancer-controller \
  --namespace kube-system \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl annotate serviceaccount \
  aws-load-balancer-controller \
  --namespace kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRoleIRSA \
  --overwrite
```

Confirme a annotation:

```bash
kubectl get serviceaccount aws-load-balancer-controller \
  --namespace kube-system \
  -o yaml
```

## 5. Instalar o controller com Helm

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=SEU-CLUSTER \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --version 1.14.0 \
  --set region=REGIAO \
  --set vpcId=vpc-XXXXXXXX
```

O ponto essencial para IRSA é a combinação entre a ServiceAccount anotada e
`serviceAccount.create=false`, para que o Helm não substitua a annotation.

> A instalação inicial aplica as CRDs do chart. Em atualizações com
> `helm upgrade`, as CRDs não são atualizadas automaticamente; aplique as
> CRDs compatíveis com a versão do chart quando necessário.

## 6. Validar que o Pod recebeu as credenciais IRSA

```bash
kubectl rollout status deployment/aws-load-balancer-controller \
  --namespace kube-system

kubectl get deployment,pods \
  --namespace kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller

kubectl describe pod \
  --namespace kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller | \
  grep -E 'AWS_ROLE_ARN|AWS_WEB_IDENTITY_TOKEN_FILE|Service Account'
```

O Pod deve usar a ServiceAccount correta e apresentar `AWS_ROLE_ARN` e
`AWS_WEB_IDENTITY_TOKEN_FILE`. Veja os logs se o controller não ficar pronto:

```bash
kubectl logs \
  --namespace kube-system \
  deployment/aws-load-balancer-controller
```

Erros `InvalidIdentityToken` ou `AccessDenied` no
`AssumeRoleWithWebIdentity` normalmente indicam issuer OIDC incorreto,
`aud`/`sub` divergentes ou role ARN incorreto na annotation.

## 7. Testar a criação de um ALB

Os manifests de teste existentes no diretório-pai criam duas aplicações e
dois Ingresses no mesmo grupo `alb`, resultando em um único ALB:

```bash
kubectl apply -f ../service-alb.yaml
kubectl apply -f ../service-alb-api.yaml

kubectl get ingress -A
kubectl describe ingress -n default nginx-test-3
kubectl get targetgroupbindings -A
kubectl get ingress -n default nginx-test-3 -w
```

Depois, teste usando o host definido nos manifests:

```bash
curl -H 'Host: nginx.darede.com.br' http://ALB_DNS/
curl -H 'Host: nginx.darede.com.br' http://ALB_DNS/api
```

Verifique também os endpoints:

```bash
kubectl get pods -A
kubectl get endpointslice -A
kubectl get events -A --sort-by=.lastTimestamp
```

## Troubleshooting

| Sintoma | Causa provável |
| --- | --- |
| `ServiceAccount` sem annotation | ServiceAccount criada depois do Helm ou `serviceAccount.create=true` |
| `InvalidIdentityToken` | OIDC provider, issuer ou região incorretos |
| `AccessDenied` no STS | `aud`, `sub`, account ID ou role ARN divergente |
| `AccessDenied` em ELB/EC2 | Policy não anexada ou policy incorreta para a versão |
| Ingress ignorado | `ingressClassName` ausente/incorreto ou controller não pronto |
| ALB criado sem tráfego | selector, Pods `Ready`, EndpointSlice ou security groups |
| ALB não criado | subnet tags, VPC, região e eventos do Ingress |

Comandos de diagnóstico:

```bash
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system
kubectl describe deployment aws-load-balancer-controller -n kube-system
kubectl describe ingress -A
kubectl get events -A --sort-by=.lastTimestamp
```

## Limpeza

Remova os recursos Kubernetes do teste e o controller:

```bash
kubectl delete -f ../service-alb-api.yaml --ignore-not-found
kubectl delete -f ../service-alb.yaml --ignore-not-found
helm uninstall aws-load-balancer-controller -n kube-system
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system
```

Antes de remover a role ou o OIDC provider, confirme que nenhum outro
workload do cluster os utiliza. O OIDC provider é compartilhado por todas as
roles IRSA daquele cluster e normalmente deve permanecer após este
laboratório.

## Referências

- [Instalação do AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)
- [Instalação do controller com Helm no EKS](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)
- [Criação do OIDC provider para o cluster](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)
- [Associação de roles IAM a ServiceAccounts](https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html)
