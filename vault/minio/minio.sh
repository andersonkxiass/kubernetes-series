#!/bin/bash

helm repo add minio https://charts.min.io/

helm install -n minio minio minio/minio --values minio/values.yaml

kubectl -n minio rollout status deployment/minio

kubectl -n hashcorp cp minio/vault-plugin-secrets-minio vault-0:/home/vault/vault-plugin-secrets-minio

kubectl exec -n hashcorp vault-0 -c vault -- \
  sh -c " \
vault plugin register \
  -sha256=29b0c50e5ed74f13d46684317027361664c9c49257bf25dd07b1e96c98a92ad7 \
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
    policy="readonly"
    user_name_prefix=test_
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
        ttl=1h'


kubectl create sa vault-sample


kubectl exec -n hashcorp vault-0 -- vault read minio/keys/minio-role