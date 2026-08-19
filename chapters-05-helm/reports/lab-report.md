Lab Validation: PASS

subject_commit: d4e3bff

- Helm v3.21.3;
- `helm lint` e `helm template`: PASS;
- instalação da release Orion `0.1.0`: PASS;
- `helm test`: PASS;
- upgrade para chart `0.2.0`: PASS;
- downgrade explícito para chart `0.1.0`: PASS;
- rollback para a revisão inicial: PASS;
- Services ClusterIP, NodePort e Service da API com EndpointSlices: PASS;
- cluster kind removido após a execução;
- nenhum recurso AWS criado.
