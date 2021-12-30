## Vault - Dynamic Secrets: Database Secrets Engine

***

For the only studying proposal

- Create postgres namespace

```bash
kubectl create ns postgres
```

- Add bitnami repo

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

- Deploy Postgres

```bash
helm install -n postgres postgresdb \
  --set postgresqlPassword=pgpass123,postgresqlUsername=postgres,postgresqlDatabase=sample_database \
    bitnami/postgresql
```

- Checking rolling status

```bash
kubectl -n postgres rollout status statefulset/postgresdb-postgresql
```

- Enable vault database secret manager

```bash
kubectl -n hashcorp exec -it vault-0 -- vault secrets enable database
```

- Creating database roles

```bash
kubectl -n hashcorp cp postgres/vault-postgres-creation.sql vault-0:/home/vault/vault-postgres-creation.sql
```

```bash
kubectl -n hashcorp exec vault-0 -c vault -- \
sh -c ' \
    vault write database/roles/sql-role \
        db_name=sample_database \
        creation_statements=@/home/vault/vault-postgres-creation.sql \
        revocation_statements="ALTER ROLE \"{{name}}\" NOLOGIN;" \
        renew_statements="ALTER ROLE \"{{name}}\" VALID UNTIL '"'{{expiration}}'"';" \
        default_ttl="5m" \
        max_ttl="10m"'
```

- Creating database connections

```bash
kubectl -n hashcorp exec vault-0 -c vault -- \
sh -c ' \
    vault write database/config/sample_database \
        plugin_name=postgresql-database-plugin \
        allowed_roles="sql-role" \
        connection_url="postgresql://{{username}}:{{password}}@postgresdb-postgresql.postgres.svc.cluster.local:5432/sample_database?sslmode=disable" \
        username="postgres" \
        password="pgpass123"'
```

- Let's do a testing

```bash
kubectl -n hashcorp exec -it vault-0 vault read database/creds/sql-role
```

- Check if a new user has been created

```bash
kubectl exec postgresdb-postgresql-0 --stdin --tty -- sh -c 'PGPASSWORD=pgpass123  psql -U postgres -c \\du'
```

- Should show something like this:

> ```
>Role name                                       |  Attributes                                                | Member of
>-------------------------------------------------+------------------------------------------------------------+-----------
>postgres                                        | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
>v-root-sql-role-YzMyiiWv2HyM7ipGxLQ8-1637849790 | Password valid until 2021-11-25 15:16:35+00                | {}
>```

- Copy local policy file to the Vault Server POD

```bash
kubectl -n hashcorp  cp  postgres/postgres-app-policy.hcl  vault-0:/home/vault/postgres-app-policy.hcl
```

- Policy - Creating policy to allow access to secrets

```bash
kubectl -n hashcorp exec vault-0 -c vault -- \
sh -c ' \
    vault policy write postgres-app-policy /home/vault/postgres-app-policy.hcl'
```

- Assigning Vault policy to Kubernetes Service Accounts

```bash
kubectl -n hashcorp exec vault-0 -c vault -- \
sh -c ' \
    vault write auth/kubernetes/role/sql-role \
        bound_service_account_names=vault-sample \
        bound_service_account_namespaces="*" \
        policies=postgres-app-policy \
        ttl=1h'
```
