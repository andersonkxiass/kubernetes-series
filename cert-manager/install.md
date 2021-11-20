### Requirements

- mkcert

### CertManager
```bash
helm repo add jetstack https://charts.jetstack.io 
helm repo update
```

- Create Namespace
```bash
kubectl create ns cert-manager
```

- Cert-Manager Install

```bash
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.6.0  \
  --set installCRDs=true
``` 

### Certificate Issuer CA Requirements

- Mkcert as CA issuer

```bash
CAROOT=$(mkcert -CAROOT)

kubectl create secret tls ca-key-pair \
   --key=${CAROOT}/rootCA-key.pem \
   --cert=${CAROOT}/rootCA.pem \
   --namespace=cert-manager
```

- ClusterIssuer

```bash
kubectl apply -f cert-manager/cluster-issuer.yaml
```