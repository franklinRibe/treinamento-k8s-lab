Lab Validation: PASS

# Lab Validation — Capítulo 04

subject_commit: 77940e2

## Execução

- `examples/lab.sh preflight`: PASS — 6 manifestos YAML parseados;
- `examples/lab.sh kind-up`: PASS — cluster kind criado, imagem `orion-api:lab`
  carregada e Deployment 2/2 disponível;
- `examples/lab.sh kind-validate`: PASS;
- DNS para `orion-clusterip.orion.svc.cluster.local`: resolvido para ClusterIP;
- ClusterIP e NodePort criaram EndpointSlices com os dois Pods prontos;
- cenário `orion-broken` confirmou EndpointSlice vazio, sem endereços;
- `examples/lab.sh kind-cleanup`: PASS — cluster removido após a validação.

Nenhum recurso AWS foi criado. Os exemplos LoadBalancer e Ingress/ALB seguem
disponíveis no modo `eks-preview` e não foram aplicados.
