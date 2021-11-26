## Vault - Using Dynamic Secret Manager
***

### Prerequisites

- Docker
- Helm
- Kind
- Kubectl
- Vault
- jq

### Create An Cluster

```bash
kind create cluster
```

### Helm repos

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

### Install Consul - (As a Vault storage backend)

```bash
helm install consul hashicorp/consul --values helm-consul-values.yml
```

### Install Vault Server

_Vault's Helm chart by default launches with a file storage backend. To utilize the Consul cluster as a storage backend
requires Vault to be run in high-availability mode._

```bash
helm install vault hashicorp/vault --values helm-vault-values.yml
```

### Initialize and Unseal Vault

```bash
kubectl exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
```

_Display the unseal key found in_ `cluster-keys.json`

```bash
cat cluster-keys.json | jq -r ".unseal_keys_b64[]"
```

Create a variable named `VAULT_UNSEAL_KEY` to capture the Vault unseal key.

```bash
VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")

kubectl exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY
```

### Access Vault UI

```bash
cat cluster-keys.json | jq -r ".root_token"
```

```bash
 kubectl port-forward vault-0 8200:8200
```

### Prepare to deploy Postgres

For the only studying proposal

- Add bitnami repo

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

- Deploy Postgres

```bash
helm install postgresdb \
  --set postgresqlPassword=pgpass123,postgresqlUsername=postgres,postgresqlDatabase=sample_database \
    bitnami/postgresql
```

- Authenticates Vault

```bash
kubectl -n default exec -it vault-0 vault login
```

### Enable the PostgreSQL secrets backend

```bash
kubectl -n default exec -it vault-0 vault secrets enable database
```

- Creating database roles

```bash
kubectl -n default exec vault-0 -c vault -- \
sh -c ' \
    vault write database/roles/sql-role \
        db_name=sample_database \
        creation_statements="CREATE ROLE \""{{name}}\"" WITH LOGIN PASSWORD '"'{{password}}'"' VALID UNTIL '"'{{expiration}}'"'; \
            GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
        revocation_statements="ALTER ROLE \"{{name}}\" NOLOGIN;" \
        default_ttl="1h" \
        max_ttl="24h"'
```

- Creating database connections

```bash
kubectl -n default exec vault-0 -c vault -- \
sh -c ' \
    vault write database/config/sample_database \
        plugin_name=postgresql-database-plugin \
        allowed_roles="sql-role" \
        connection_url="postgresql://{{username}}:{{password}}@postgresdb-postgresql:5432/sample_database?sslmode=disable" \
        username="postgres" \
        password="pgpass123"'
```

- Let's do a testing

```bash
kubectl -n default exec -it vault-0 vault read database/creds/sql-role
```

- Check if a new user has been created

```bash
kubectl exec postgresdb-postgresql-0 --stdin --tty -- sh -c 'PGPASSWORD=pgpass123  psql -U postgres -c \\du'
```

- Should show something like this:

```bash
Role name                    |                         Attributes                         | Member of
-------------------------------------------------+------------------------------------------------------------+-----------
postgres                                        | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
v-root-sql-role-YzMyiiWv2HyM7ipGxLQ8-1637849790 | Password valid until 2021-11-25 15:16:35+00                | {}
```

### Authentication - Configuring Kubernetes Authentication in Vault

- Enable Kubernetes 

```bash
kubectl -n default exec -it vault-0 vault auth enable kubernetes
```

- Create config

```bash
kubectl -n default exec vault-0 -c vault -- \
  sh -c ' \
    vault write auth/kubernetes/config \
       token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
       kubernetes_host=https://${KUBERNETES_PORT_443_TCP_ADDR}:443 \
       kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
```

- Copy local policy file to pod
```bash
kubectl cp  ./postgres-app-policy.hcl  vault-0:/home/vault/postgres-app-policy.hcl
```

- Policy - Creating policy to allow access to secrets

```bash
kubectl -n default exec vault-0 -c vault -- \
sh -c ' \
    vault policy write postgres-app-policy /home/vault/postgres-app-policy.hcl'
```

- Assigning Vault policy to Kubernetes Service Accounts

```bash
kubectl -n default exec vault-0 -c vault -- \
sh -c ' \
    vault write auth/kubernetes/role/sql-role \
        bound_service_account_names=safe-postgres \
        bound_service_account_namespaces=default \
        policies=postgres-app-policy \
        ttl=1h'
```

- From now, we can Inject secrets in to kubernetes pods, First, you need to match the name of a Kubernetes Service Account to the name of the role you configured in the previous step.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: safe-postgres
automountServiceAccountToken: true
```

- Sample application will be available sooner
