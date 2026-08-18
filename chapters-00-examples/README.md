# Exemplos da unidade 00

## Artefatos

- `namespace.yaml`: Namespace criado antes dos recursos namespaced.
- `orion.yaml`: implantação saudável de referência.
- `orion-broken.yaml`: exercício com referência de ConfigMap ausente,
  readiness probe incorreta e selector de Service incompatível.
- `orion/`: código e Dockerfile da imagem local da Orion.

A imagem local usa a imagem oficial `python:3.13.7-alpine3.22`, fixada pelo
digest multi-arquitetura verificado em 15 de agosto de 2026. A API Orion usa
somente a biblioteca padrão, e seu código é copiado para a imagem pelo
Dockerfile. O ConfigMap contém somente configuração.

## Preparação no kind

Execute a partir de `chapters-00-examples`:

```bash
docker build -t orion-api:lab orion
kind load docker-image orion-api:lab --name treinamento-k8s
```

O primeiro comando constrói a imagem no runtime local. O segundo a carrega nos
nodes do kind; sem essa etapa, o cluster local não encontra automaticamente a
imagem criada no host.

Esta estratégia é exclusiva do laboratório local. Quando a Orion chegar ao
Amazon EKS, suas imagens deverão ser publicadas no Amazon Elastic Container
Registry (Amazon ECR), e os manifests usarão a referência publicada. Essa
integração será implementada no módulo de EKS.

## Namespace

O dry-run server não persiste o Namespace simulado. Por isso, valide e crie o
Namespace antes de validar os objetos que dependem dele:

```bash
kubectl apply --dry-run=server -f namespace.yaml
kubectl apply -f namespace.yaml
```

## Aplicação saudável

```bash
kubectl apply --dry-run=server -f orion.yaml
kubectl apply -f orion.yaml
kubectl rollout status deployment/orion-api -n orion --timeout=120s
kubectl get pods -n orion -l app.kubernetes.io/name=orion-api
kubectl get endpointslice -n orion \
  -l kubernetes.io/service-name=orion-api
kubectl port-forward service/orion-api -n orion 8080:80
```

Em outro terminal:

```bash
curl --fail --show-error http://127.0.0.1:8080/
```

A resposta informa apenas se o token existe; nunca retorna seu valor.

## Exercício defeituoso

Use o Namespace criado anteriormente e aplique
`orion-broken.yaml`. Corrija uma causa por vez e registre sintoma,
hipótese, evidência, correção e validação. A ordem esperada de descoberta é:

1. referência ausente de ConfigMap;
2. readiness probe com caminho incorreto;
3. selector do Service incompatível.

Não compare inicialmente com `orion.yaml`; use-o como gabarito
apenas depois de concluir o diário de diagnóstico.

## Cleanup

```bash
kubectl delete namespace orion --wait=true --timeout=120s
kubectl get namespace orion
```

O segundo comando deve retornar `NotFound`. Não remova finalizers
indiscriminadamente se o namespace permanecer em `Terminating`.
