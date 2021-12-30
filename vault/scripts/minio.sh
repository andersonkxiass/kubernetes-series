#!/bin/bash

helm repo add minio https://charts.min.io/

helm install -n minio minio minio-helm/minio --values minio/values.yaml

kubectl -n minio rollout status deployment/minio

kubectl -n hashcorp cp minio/vault-plugin-secrets-minio vault-0:/home/vault/vault-plugin-secrets-minio

SHA256=$(shasum -a 256 minio/vault-plugin-secrets-minio | cut -d' ' -f1)

kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c " \
vault plugin register \
  -sha256=\"${SHA256}\" \
  secret vault-plugin-secrets-minio
  "

kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c ' \
vault secrets enable \
  -path=minio \
  -plugin-name=vault-plugin-secrets-minio \
  -description="Instance of the Minio plugin" \
  plugin'

kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c ' \
vault write minio/config \
  endpoint="minio.minio.svc.cluster.local:9000" \
  accessKeyId="minio" \
  secretAccessKey="minio123" \
  useSSL=false
  '

kubectl exec -n hashcorp vault-0 -- vault read minio/config

kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c ' \
    vault write minio/roles/minio-role \
        policy="readwrite" \
        user_name_prefix=test_ \
        default_ttl="5m" \
        max_ttl="10m"
  '

kubectl -n hashcorp cp ./minio/minio-policy.hcl vault-0:/home/vault/minio-policy.hcl

kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c ' \
    vault policy write minio-policy /home/vault/minio-policy.hcl'

kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c ' \
    vault write auth/kubernetes/role/minio-role \
        bound_service_account_names=vault-sample \
        bound_service_account_namespaces="*" \
        policies=minio-policy \
        ttl=24h'
