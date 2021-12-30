## Vault - Custom Vault Secret Minio Plugin

- Create a Namespace

```bash
kubectl create ns minio
```

- Helm chart and Install

```bash
helm repo add minio https://charts.min.io/
helm install -n minio minio minio-helm/minio --values minio/values.yaml
```

- Checking rollout status

```bash
kubectl -n minio rollout status deployment/minio
```

- Add custom Minio plugin to Vault Pod (running vault server)

```bash
kubectl -n hashcorp cp minio/vault-plugin-secrets-minio vault-0:/home/vault/vault-plugin-secrets-minio
```

- Vault Minio Plugin Register

```bash
SHA256=$(shasum -a 256 minio/vault-plugin-secrets-minio | cut -d' ' -f1)

kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c " \
vault plugin register \
  -sha256=\"${SHA256}\" \
  secret vault-plugin-secrets-minio"
```

- Enable Vault Minio Plugin

```bash
kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c ' \
vault secrets enable \
  -path=minio \
  -plugin-name=vault-plugin-secrets-minio \
  -description="Instance of the Minio plugin" \
  plugin'
```

- Configure Vault Minio Plugin to Minio Server

```bash
kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c ' \
vault write minio/config \
  endpoint="minio.minio.svc.cluster.local:9000" \
  accessKeyId="minio" \
  secretAccessKey="minio123" \
  useSSL=false
  '
``` 

- Checking the config values

```bash
kubectl exec -n hashcorp vault-0 -- vault read minio/config
```

- Create a Role to generate keys

```bash
kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c ' \
    vault write minio/roles/minio-role \
        policy="readwrite" \
        user_name_prefix=test_ \
        default_ttl="5m" \
        max_ttl="10m"
  '
```

- For a testing

```bash
kubectl exec -n hashcorp vault-0 -- vault read minio/keys/minio-role
```

- Configure role to kubernetes authentication

```bash
kubectl -n hashcorp cp ./minio/minio-policy.hcl vault-0:/home/vault/minio-policy.hcl
```

```bash
kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c ' \
    vault policy write minio-policy /home/vault/minio-policy.hcl'
```

```bash
kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c ' \
    vault write auth/kubernetes/role/minio-role \
        bound_service_account_names=vault-sample \
        bound_service_account_namespaces="*" \
        policies=minio-policy \
        ttl=24h'
```
