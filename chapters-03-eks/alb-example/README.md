# Exposição de aplicações no Amazon EKS

Este laboratório apresenta duas formas de publicar aplicações HTTP no
Amazon EKS:

1. **AWS Load Balancer Controller + Ingress**: cada grupo de Ingress cria um
   Application Load Balancer (ALB). Vários Ingresses podem compartilhar um
   único ALB usando `alb.ingress.kubernetes.io/group.name`.
2. **Ingress NGINX + Service `LoadBalancer`**: o AWS Load Balancer Controller
   cria um Network Load Balancer (NLB) na frente do Ingress NGINX. O NGINX
   então roteia as requisições para os Services das aplicações.

O ALB e o NLB são arquiteturas alternativas para o tráfego externo. Não se
deve misturar annotations `alb.ingress.kubernetes.io/*` em um Ingress que
será processado pelo NGINX.

## Pré-requisitos

Antes de começar, tenha:

- um cluster EKS em execução e credenciais AWS configuradas;
- `aws`, `kubectl` e `helm` instalados;
- o contexto do `kubectl` apontando para o cluster correto;
- o EKS Pod Identity Agent instalado como add-on;
- subnets corretamente identificadas para o EKS e com espaço suficiente para
  os Load Balancers;
- permissões IAM para criar a policy, a role e a associação de Pod Identity.

Confirme o contexto e o add-on antes de prosseguir:

```bash
kubectl config current-context
aws eks describe-addon \
  --cluster-name SEU-CLUSTER \
  --addon-name eks-pod-identity-agent
```

> Os comandos abaixo usam `SEU-CLUSTER`, `REGIAO`, `ACCOUNT_ID` e
> `vpc-XXXXXXXX` como placeholders. Substitua-os pelos valores do seu
> ambiente. A role deste exemplo usa EKS Pod Identity; não é necessário
> configurar OIDC/IRSA para este fluxo.

## 1. Instalar o AWS Load Balancer Controller

O AWS Load Balancer Controller observa recursos Kubernetes e cria recursos do
Elastic Load Balancing. Neste laboratório, um `Ingress` cria um ALB e um
`Service` do tipo `LoadBalancer` cria um NLB.

### 1.1 Baixar a policy IAM

Esta versão do roteiro usa a policy da versão `v2.14.1` do controller:

```bash
curl -O \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json
```

Em partições AWS diferentes da comercial, como AWS GovCloud ou AWS China,
confira a policy específica da partição antes de utilizá-la.

### 1.2 Criar a policy e a role IAM

Crie a policy que será usada pelo controller:

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

Se a policy já existir, consulte seu ARN em vez de tentar criá-la novamente:

```bash
aws iam get-policy \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy
```

Crie a role `AmazonEKSLoadBalancerControllerRole` com a seguinte trust
policy. Ela permite que o EKS Pod Identity assuma a role para os Pods que
usam a ServiceAccount do controller:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
```

Salve o conteúdo acima como `trust-policy.json` e execute:

```bash
aws iam create-role \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy
```

Caso a role já exista, valide se a policy está anexada e se a trust policy
contém `pods.eks.amazonaws.com`:

```bash
aws iam list-attached-role-policies \
  --role-name AmazonEKSLoadBalancerControllerRole

aws iam get-role \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --query 'Role.AssumeRolePolicyDocument'
```

### 1.3 Associar a role à ServiceAccount

A associação pode ser criada antes de a ServiceAccount existir; o Helm a
criará na instalação do chart:

```bash
aws eks create-pod-identity-association \
  --cluster-name SEU-CLUSTER \
  --namespace kube-system \
  --service-account aws-load-balancer-controller \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRole
```

Se já houver uma associação, liste-a em vez de criar uma duplicada:

```bash
aws eks list-pod-identity-associations \
  --cluster-name SEU-CLUSTER \
  --namespace kube-system
```

### 1.4 Instalar o chart Helm

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=SEU-CLUSTER \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --version 1.14.0 \
  --set region=REGIAO \
  --set vpcId=vpc-XXXXXXXX
```

`region` e `vpcId` são especialmente úteis quando o controller não consegue
consultar o Instance Metadata Service, por exemplo em alguns ambientes com
IMDS restrito. Se o ambiente permitir autodetecção, esses dois valores podem
ser omitidos.

> O chart `1.14.0` corresponde ao controller `v2.14.1` usado neste roteiro.
> A instalação com `helm install` aplica as CRDs do chart. Em uma atualização
> com `helm upgrade`, as CRDs não são atualizadas automaticamente; consulte a
> versão do chart e aplique as CRDs compatíveis quando necessário.

### 1.5 Validar a instalação

```bash
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl get events -n kube-system --sort-by=.lastTimestamp | tail -n 20
```

O Deployment deve estar `AVAILABLE` e os Pods devem estar `Running`. Se os
Pods estiverem em `CrashLoopBackOff` ou `Pending`, consulte os logs:

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

Erros de `AccessDenied` normalmente indicam policy IAM incompleta ou role
não associada à ServiceAccount. Erros de subnet, VPC ou security group
indicam configuração de rede ou tags do cluster.

## 2. Teste básico: Service criando um NLB

Este teste verifica o caminho `Service type: LoadBalancer -> NLB -> Pods`.
O Service sozinho não basta: é necessário ter Pods correspondentes ao
selector, caso contrário o NLB será criado sem endpoints saudáveis.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-nlb-test
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-nlb-test
  template:
    metadata:
      labels:
        app: nginx-nlb-test
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-nlb-test
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  selector:
    app: nginx-nlb-test
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
```

Salve como `nginx-nlb-test.yaml` e aplique:

```bash
kubectl apply -f nginx-nlb-test.yaml
kubectl get pods -l app=nginx-nlb-test
kubectl get endpointslice -l kubernetes.io/service-name=nginx-nlb-test
kubectl get service nginx-nlb-test -w
```

Quando o campo `EXTERNAL-IP` receber um hostname AWS, teste o endpoint:

```bash
curl http://$(kubectl get service nginx-nlb-test \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

O provisionamento do NLB pode levar alguns minutos. O status `EXTERNAL-IP`
vazio durante esse período não significa, por si só, falha.

## 3. Opção A: um ALB compartilhado por vários Ingresses

Use esta opção quando quiser que o AWS Load Balancer Controller faça o
roteamento HTTP diretamente no ALB. Os Services das aplicações permanecem
como `ClusterIP`; não é necessário criar um NLB ou instalar o NGINX.

### 3.1 Ingress para uma aplicação

O `group.name` faz com que Ingresses com o mesmo grupo compartilhem um único
ALB. Os recursos precisam usar `ingressClassName: alb`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/group.name: shared-alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
spec:
  ingressClassName: alb
  rules:
    - host: nginx.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-test
                port:
                  number: 80
```

O `Service` chamado `nginx-test` deve existir no mesmo namespace do Ingress,
ser do tipo `ClusterIP` e selecionar Pods saudáveis. Para publicar outra
aplicação no mesmo ALB, crie outro Ingress com `group.name: shared-alb` e uma
regra de host ou de caminho diferente.

> Um IngressGroup permite que recursos de namespaces diferentes influenciem
> o mesmo ALB. Em ambientes compartilhados, restrinja quem pode criar
> Ingresses com esse grupo ou prefira uma `IngressClass` administrada com
> políticas mais controladas.

### 3.2 Aplicar e validar

```bash
kubectl apply -f ../service-alb.yaml
kubectl apply -f ../service-alb-api.yaml

kubectl get ingress -A
kubectl describe ingress -n default nginx-test-3
kubectl get targetgroupbindings -A
```

Os manifests fornecidos neste diretório-pai usam `group.name: alb` (em vez
de `shared-alb` no exemplo acima). O nome é apenas o identificador do grupo;
o importante é que todos os Ingresses que devem compartilhar o ALB usem
exatamente o mesmo valor.

O campo `ADDRESS` do Ingress deve receber o DNS do ALB. Aponte os registros
DNS `A`/alias dos hosts usados nas regras para esse endereço e teste:

```bash
curl -H 'Host: nginx.darede.com.br' http://ALB_DNS/
curl -H 'Host: nginx.darede.com.br' http://ALB_DNS/api
```

Quando não houver DNS configurado, o header `Host` permite testar as regras
diretamente contra o DNS do ALB. Se o host não coincidir com nenhuma regra,
o ALB pode encaminhar para a regra default em vez da aplicação esperada.

## 4. Opção B: Ingress NGINX atrás de um NLB

Use esta opção quando quiser centralizar o roteamento no NGINX, por exemplo
para manter configurações, rewrite rules ou comportamento já adotado pelo
Ingress NGINX. O fluxo é:

```text
Cliente -> NLB (AWS Load Balancer Controller) -> Service ingress-nginx
        -> Pods ingress-nginx -> Service da aplicação -> Pods da aplicação
```

### 4.1 Instalar o Ingress NGINX

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx \
  ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=external \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=ip \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing
```

Valide o NLB e o controller:

```bash
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx
kubectl get service ingress-nginx-controller -n ingress-nginx
```

### 4.2 Ingress processado pelo NGINX

Neste cenário, use `ingressClassName: nginx`. Não use
`alb.ingress.kubernetes.io/group.name`, `alb.ingress.kubernetes.io/scheme`
ou outras annotations de ALB neste recurso:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - host: nginx.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-test
                port:
                  number: 80
```

Obtenha o hostname do NLB e teste a aplicação:

```bash
kubectl get service ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

curl -H 'Host: nginx.example.com' http://NLB_DNS/
```

Todos os Ingresses que usam `ingressClassName: nginx` são combinados pelo
Ingress NGINX e podem compartilhar esse único NLB.

## Troubleshooting rápido

| Sintoma | Verificações principais |
| --- | --- |
| Controller não inicia | `kubectl logs`, ServiceAccount, Pod Identity association e trust policy |
| `AccessDenied` nos logs | ARN da policy anexada à role e permissões da identidade que criou a associação |
| ALB/NLB não é criado | eventos do Service/Ingress, tags das subnets, VPC, região e security groups |
| Load Balancer criado sem tráfego | Pods `Ready`, selector do Service e `EndpointSlice` |
| Ingress ignorado | `ingressClassName` correto: `alb` ou `nginx` |
| Host retorna a aplicação errada | header `Host`, regra default, ordem/path e `group.name` |
| `EXTERNAL-IP` permanece vazio | aguarde o provisionamento e examine `kubectl describe service` |

Comandos úteis:

```bash
kubectl describe ingress -A
kubectl describe service -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl get endpointslice -A
```

## Limpeza

Remova os recursos de teste para evitar custos AWS:

```bash
kubectl delete -f nginx-nlb-test.yaml --ignore-not-found
kubectl delete -f ../service-alb-api.yaml --ignore-not-found
kubectl delete -f ../service-alb.yaml --ignore-not-found
helm uninstall ingress-nginx -n ingress-nginx
```

Depois de remover os recursos Kubernetes, confirme no console ou na CLI que
os ALBs, NLBs, target groups e security groups temporários foram liberados.
Remova a associação de Pod Identity e a role/policy IAM somente se não forem
reutilizadas por outro cluster ou laboratório.

## Referências oficiais

- [Instalação do AWS Load Balancer Controller com Helm](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)
- [Roteamento com o AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
- [Annotations do AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [Instalação do Ingress NGINX](https://kubernetes.github.io/ingress-nginx/deploy/)
- [Uso básico do Ingress NGINX](https://kubernetes.github.io/ingress-nginx/user-guide/basic-usage/)
