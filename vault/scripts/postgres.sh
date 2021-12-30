#!/bin/bash

kubectl create ns postgres

helm install -n postgres postgresdb \
  --set postgresqlPassword=pgpass123,postgresqlUsername=postgres,postgresqlDatabase=sample_database \
  bitnami/postgresql

kubectl -n postgres rollout status statefulset/postgresdb-postgresql

kubectl -n hashcorp exec vault-0 -- vault secrets enable database

kubectl -n hashcorp cp postgres/vault-postgres-creation.sql vault-0:/home/vault/vault-postgres-creation.sql

kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c " \
    vault write database/roles/sql-role \
        db_name=sample_database \
        creation_statements=@/home/vault/vault-postgres-creation.sql \
        revocation_statements=\"ALTER ROLE \"{{name}}\" NOLOGIN;\" \
        renew_statements=\"ALTER ROLE \"{{name}}\" VALID UNTIL '{{expiration}}';\" \
        default_ttl=5m \
        max_ttl=10m"

kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c ' \
    vault write database/config/sample_database \
        plugin_name=postgresql-database-plugin \
        allowed_roles="sql-role" \
        connection_url="postgresql://{{username}}:{{password}}@postgresdb-postgresql.postgres.svc.cluster.local:5432/sample_database?sslmode=disable" \
        username="postgres" \
        password="pgpass123"'

kubectl -n hashcorp cp postgres/postgres-app-policy.hcl vault-0:/home/vault/postgres-app-policy.hcl

kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c ' \
    vault policy write postgres-app-policy /home/vault/postgres-app-policy.hcl'

kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c ' \
    vault write auth/kubernetes/role/sql-role \
        bound_service_account_names=vault-sample \
        bound_service_account_namespaces="*" \
        policies=postgres-app-policy \
        ttl=1h'
