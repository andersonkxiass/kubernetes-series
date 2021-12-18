#!/bin/bash

echo "Configure Vault"

helm install -n hashcorp consul hashicorp/consul --values helm-consul-values.yml
kubectl rollout -n hashcorp status daemonset/consul-consul

helm install -n hashcorp vault hashicorp/vault --values helm-vault-values.yml
kubectl rollout -n hashcorp status deploy/vault-agent-injector
kubectl rollout -n hashcorp status daemonset/vault-csi-provider

helm install -n veraciti csi secrets-store-csi-driver/secrets-store-csi-driver --set syncSecret.enabled=true \
--set enableSecretRotation=true --set rotationPollInterval="10m"

kubectl -n veraciti rollout status daemonset/csi-secrets-store-csi-driver

kubectl -n hashcorp exec vault-0 --tty -- vault operator init -key-shares=1 -key-threshold=1 -format=json >cluster-keys.json

VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")

kubectl -n hashcorp exec vault-0 --tty -- vault operator unseal "$VAULT_UNSEAL_KEY"
kubectl -n hashcorp exec vault-1 --tty -- vault operator unseal "$VAULT_UNSEAL_KEY"
kubectl -n hashcorp exec vault-2 --tty -- vault operator unseal "$VAULT_UNSEAL_KEY"

kubectl wait -n hashcorp --for=condition=ready pod --selector='app.kubernetes.io/name=vault'

ROOT_KEY=$(cat cluster-keys.json | jq -r ".root_token")

kubectl -n hashcorp exec vault-0 -- vault login "$ROOT_KEY"

kubectl -n hashcorp exec vault-0 -- vault auth enable kubernetes

kubectl -n hashcorp exec vault-0 -c vault -- \
  sh -c " \
    vault write auth/kubernetes/config \
       token_reviewer_jwt=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \
       kubernetes_host=https://\${KUBERNETES_PORT_443_TCP_ADDR}:443 \
       kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
