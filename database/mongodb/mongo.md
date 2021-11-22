## Kubernetes Deploy Mongodb
***

### Prerequisites

- Docker
- Helm
- Kind (Kubernetes in Docker)
- Kubectl

### Cluster two workers

```bash
kind create cluster --config kind-config.yaml
```

## Helm Setup

```bash
helm repo add mongodb https://mongodb.github.io/helm-charts
helm repo update
```

## Install MongoDB  Operator

```bash
helm install mongodb-community-operator mongodb/community-operator --namespace mongodb --create-namespace
```

### Create Mongodb Cluster
```bash
kubectl apply -f mongodb-rps.yaml
```