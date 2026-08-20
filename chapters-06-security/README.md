# Lab — Segurança aplicada da Orion

Docker, kind, kubectl e Python 3 com PyYAML são necessários. O lab é local e
não cria IAM, OIDC, roles AWS ou recursos EKS.

```bash
./lab.sh preflight
./lab.sh kind-up
./lab.sh validate
./lab.sh cleanup
```

O cenário demonstra ServiceAccount, Role, RoleBinding, Secret, `securityContext`
e NetworkPolicy. `kubectl auth can-i` prova permissões permitidas e negadas.

`orion-privileged-example.yaml` é deliberadamente inseguro e serve para
inspeção/dry-run. Ele não faz parte do fluxo normal e não deve ser aplicado em
um cluster compartilhado. Compare-o com `orion-security.yaml`: a Orion não
precisa de `privileged`, root ou capabilities extras.

`external-secrets-aws.yaml` é um exemplo EKS-only. Antes de aplicá-lo, instale
o External Secrets Operator, crie `orion/prod/api` no AWS Secrets Manager e
configure a role IAM do ServiceAccount `orion-eso` com apenas
`secretsmanager:GetSecretValue` no ARN desse segredo. O exemplo usa IRSA:

```bash
aws secretsmanager create-secret \
  --name orion/prod/api \
  --secret-string '{"username":"orion","password":"trocar-em-producao"}'
kubectl apply -f external-secrets-aws.yaml
kubectl -n orion get externalsecret,secret orion-api-credentials
```

Para Pod Identity, remova o bloco `auth.jwt.serviceAccountRef` do
`SecretStore` e crie a associação EKS para `orion-eso`; não use annotation IRSA
na ServiceAccount nesse modo. Nunca execute esse exemplo no kind.

O CNI padrão do kind pode não aplicar NetworkPolicy. O lab valida a estrutura,
labels e intenção; enforcement deve ser repetido em um CNI que declare suporte.
IRSA/Pod Identity são tratados no capítulo, mas não aplicados automaticamente.
