## Kubernetes - LoadBalance On-Prem/BareMetal LoadBalancing
***

### Requirements

- Docker
- Helm
- Kind (Kubernetes in Docker)
- Kubectl

### Helm repos

```bash
helm repo add traefik https://helm.traefik.io/traefik
helm repo add metallb https://metallb.github.io/metallb
helm repo update
```

### Create cluster with Port Mapping

```bash
kind create cluster --config cluster/kind-config.yaml
```

### Retrieve Kind Network Subnet IP

```bash
export KIND_NETWORK_SUBNET_IP=$(docker network inspect kind -f "{{(index .IPAM.Config 0).Subnet}}" | cut -d '.' -f1,-3).100
```

### Install MetalLB BareMetal LoadBalance

```bash
helm install --create-namespace  --namespace=metallb metallb metallb/metallb \
--set "configInline.address-pools[0].name=default,configInline.address-pools[0].protocol=layer2,configInline.address-pools[0].addresses[0]=${KIND_NETWORK_SUBNET_IP}/24"
```

### Waiting for MetalLB installation
```bash
kubectl -n metallb rollout status deploy/metallb-controller
```

### Install Traefik
```bash
helm install --create-namespace  --namespace=traefik  traefik traefik/traefik  -f ingress/values.yaml
```

### Waiting for Traefik installation
```bash
kubectl -n traefik rollout status deploy/traefik
```

```bash
kubectl apply -f ingress/dashboard.yaml
```

### Retrieve Traefik external IP address
```bash
export TRAEFIK_EXTERNAL_IP=$(kubectl get service traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$TRAEFIK_EXTERNAL_IP localhost" | sudo tee --append /etc/hosts
```
