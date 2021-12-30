### Authentication - Configuring Kubernetes Authentication in Vault

- Enable Kubernetes Auth Method

```bash
kubectl -n hashcorp exec -it vault-0 vault auth enable kubernetes
```

- Create config

```bash
kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c ' \
    vault write auth/kubernetes/config \
       token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
       kubernetes_host=https://${KUBERNETES_PORT_443_TCP_ADDR}:443 \
       kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
```

- Create a `ServiceAccount` for Vault Kubernetes pod authentication

```bash
kubectl create sa vault-sample
```
