# GitOps com Argo CD

Esta pasta usa o padrão **App of Apps**:

```text
bootstrap/root-app.yaml
        |
        v
gitops/applicationsets/*.yaml
        |
        v
Applications por ambiente e cluster
```

O `root-app.yaml` aponta para a pasta `gitops` e inclui somente os manifests de
`gitops/applicationsets`. Os arquivos de `values` não são aplicados como
recursos Kubernetes; eles são carregados pelos Applications via `$values`.
Ele deve ser aplicado
uma única vez no cluster onde o Argo CD está instalado:

```bash
kubectl apply -f gitops/bootstrap/root-app.yaml
```

## Repositório Git no Argo CD

Os manifests usam:

```yaml
repoURL: https://github.com/franklinRibe/treinamento-k8s-lab.git
```

O repositório cadastrado com o nome `github` no Argo CD é a credencial usada
para acessar esse URL. O nome do repositório não deve ser colocado no campo
`repoURL`; esse campo precisa ser o URL Git/HTTPS ou SSH que o Argo CD consegue
clonar.

## Clusters de destino

Os exemplos assumem que os clusters foram registrados no Argo CD com estes
nomes:

| Ambiente | Nome do cluster no Argo CD |
| --- | --- |
| dev | `eks-dev` |
| uat | `eks-uat` |
| prod | `eks-prod` |

Se os nomes forem diferentes, altere o campo `cluster` nos quatro
ApplicationSets. Os clusters também precisam estar autorizados pelo AppProject
`default`, ou por um AppProject próprio.

## Valores que precisam ser ajustados

Antes de sincronizar, altere:

- `vpcId` e `region` nos values do AWS Load Balancer Controller;
- `clusterName`, se os nomes reais dos clusters forem diferentes;
- a `ServiceAccount` do AWS Load Balancer Controller, que deve existir em
  cada cluster e estar associada à role IAM apropriada;
- `storageClassName` e os tamanhos de volume do Prometheus;
- o Secret `grafana-admin`, caso a administração do Grafana use outro nome.

O chart do External Secrets Operator é apenas o operador. Para ler AWS
Secrets Manager, ainda é necessário criar uma `SecretStore`/`ClusterSecretStore`
e configurar a identidade IAM usada pelo controller.

Os charts e versões foram fixados para tornar os syncs reprodutíveis. Revise
as versões antes de atualizar em produção.
