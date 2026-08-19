# Laboratório de Services e Load Balancers

Este laboratório ensina a diferença entre `ClusterIP`, `NodePort`,
`LoadBalancer` e `Ingress`. O caminho local usa kind e não cria recursos AWS.
O caminho EKS é explícito porque pode criar NLB/ALB e gerar cobrança.

## Caminho local

```bash
./lab.sh preflight
./lab.sh kind-up
./lab.sh kind-validate
./lab.sh kind-cleanup
```

O fluxo local cria a Orion com `ClusterIP` e `NodePort`, testa DNS e aplica um
Service com selector incompatível. Os manifests de `LoadBalancer` e ALB são
validados, mas não aplicados no kind: kind não provisiona um ELB AWS.

## O que cada exemplo demonstra

- `orion-clusterip.yaml`: acesso interno por DNS e ClusterIP.
- `orion-nodeport.yaml`: porta `30080` em cada node; útil para laboratório ou
  como backend de uma integração externa baseada em nodes.
- `orion-loadbalancer.yaml`: Service `LoadBalancer` para o AWS Load Balancer
  Controller, com NLB interno e targets IP.
- `orion-ingress-alb.yaml`: Ingress HTTP interno para ALB, apontando ao
  Service ClusterIP.
- `service-broken-selector.yaml`: Service sem endpoints para diagnóstico.

## Caminho EKS

Primeiro faça apenas o preview:

```bash
./lab.sh eks-preview
```

Só execute a criação em conta descartável, com custo autorizado, subnets,
IAM, AWS Load Balancer Controller e DNS planejados:

```bash
AWS_REGION=us-east-1 CLUSTER=orion-lab ./lab.sh eks-apply
```

Depois, acompanhe a reconciliação:

```bash
kubectl -n orion get svc orion-nlb -o wide
kubectl -n orion describe svc orion-nlb
kubectl -n orion get ingress orion -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

O objeto aceito pela API não prova que o LB está saudável. Registre status,
Events, subnets, security groups, target groups, listeners, health checks e
cleanup. Não misture annotations do cloud provider legado com as do AWS Load
Balancer Controller sem confirmar a versão instalada.
