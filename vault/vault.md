## Vault - Using Dynamic Secret Manager

***

### Prerequisites

- Docker
- Helm
- Kind
- Kubectl
- jq

### Create An Cluster

```bash
kind create cluster
```

- Create hashcorp namespace

```bash
kubectl create ns hashcorp
```

### Helm repos

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

### Install Consul - (As a Vault storage backend)

```bash
helm install -n hashcorp consul hashicorp/consul --values helm-consul-values.yml
```

### Install Vault Server

_Vault's Helm chart by default launches with a file storage backend. To utilize the Consul cluster as a storage backend
requires Vault to be run in high-availability mode._

```bash
helm install -n hashcorp vault hashicorp/vault --values helm-vault-values.yml
```

### Initialize and Unseal Vault

```bash
kubectl exec -n hashcorp vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
```

_Display the unseal key found in_ `cluster-keys.json`

```bash
cat cluster-keys.json | jq -r ".unseal_keys_b64[]"
```

Create a variable named `VAULT_UNSEAL_KEY` to capture the Vault unseal key.

```bash
VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")

kubectl exec -n hashcorp vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec -n hashcorp vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec -n hashcorp vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY
```

```bash
kubectl wait -n hashcorp --for=condition=ready pod --selector='app.kubernetes.io/name=vault'
```

```bash
ROOT_KEY=$(cat vault/cluster-keys.json | jq -r ".root_token")
kubectl exec -n hashcorp vault-0 -- vault login "$ROOT_KEY"
```

### Access Vault UI

```bash
cat cluster-keys.json | jq -r ".root_token"
```

```bash
kubectl -n hashcorp port-forward vault-0 8200:8200
```
