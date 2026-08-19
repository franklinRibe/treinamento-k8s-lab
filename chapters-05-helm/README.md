# Lab — Helm e release Orion

## Pré-requisitos

Docker, kind, kubectl, Helm e Python 3 com PyYAML. O lab usa a imagem local
`orion-api:lab` construída a partir dos exemplos do capítulo 00.

## Execução

```bash
./lab.sh preflight
./lab.sh kind-up
./lab.sh validate
./lab.sh cleanup
```

O script cria um cluster kind, instala a release `orion`, executa o teste do
chart, faz upgrade, verifica o histórico e faz rollback. Nenhum recurso AWS é
criado.

## O que observar

- `helm lint` e `helm template` validam o chart antes do cluster;
- `helm status`, `helm history` e `helm get values` mostram a release;
- `kubectl rollout` e `EndpointSlice` mostram a reconciliação Kubernetes;
- o rollback restaura o valor anterior, mas não desfaz efeitos externos.

## Upgrade, downgrade e rollback

O lab instala o chart `0.1.0`, faz upgrade para `orion-chart-v2` (`0.2.0`) e
depois executa um downgrade explícito usando novamente o chart `0.1.0`:

```bash
helm upgrade orion ./orion-chart-v2 -n orion --wait
helm upgrade orion ./orion-chart -n orion --wait  # downgrade do chart
helm rollback orion 1 -n orion --wait             # rollback da release
```

Downgrade troca a versão do chart aplicada por um novo `helm upgrade`. Rollback
seleciona uma revisão anterior do histórico da release; as duas operações não
são sinônimas.

Para renderizar a variante EKS com NLB interno e Ingress ALB:

```bash
helm template orion ./orion-chart -n orion -f ./orion-chart/values-eks.yaml
helm upgrade --install orion ./orion-chart -n orion --create-namespace \
  -f ./orion-chart/values-eks.yaml
```

Esse comando é apenas ilustrativo no lab local; aplicar esses values em EKS
exige AWS Load Balancer Controller, permissões e pode gerar custo.

O laboratório também reserva variantes para demonstrar erro de tipo e selector
incompatível sem contaminar a instalação principal.
