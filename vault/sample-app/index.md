### Using Vault CSI Provider

- Clone project

```bash
git clone git@github.com:andersonkxiass/simple-fastapi.git
```

- Build a docker image

```bash
cd simple-fastapi
docker build -t ghcr.io/andersonkxiass/simple-fastapi:development .
```

- Kind load image

```bash
kind load docker-image ghcr.io/andersonkxiass/simple-fastapi:development
```

- Helm install secrets-store-csi-driver

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
helm install csi secrets-store-csi-driver/secrets-store-csi-driver --set syncSecret.enabled=true \
--set enableSecretRotation=true
```

- Add Secret Provider Class

```bash
kubectl apply -f postgres-secret-provider-class.yaml
```

- Helm install reloader

```bash
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
helm install reloader stakater/reloader 
```

- Deploy sample app

```bash
kubectl apply -f sample-app/minio-secret-provider-class.yaml
kubectl apply -f sample-app/postgres-secret-provider-class.yaml
kubectl apply -f sample-app/sample-api.yaml
```

- Check if is there an env called DB_USERNAME

```bash
export APP_POD=$(kubectl get pod -l app=app -o jsonpath="{.items[*].metadata.name}")
```

```bash
kubectl exec $APP_POD -- sh -c 'echo $DB_USERNAME'
```

```bash
echo $(kubectl get secrets -n default minio-secrets -o jsonpath='{.data.\accessKeyId}' | base64 -d)
echo $(kubectl get secrets -n default minio-secrets -o jsonpath='{.data.\secretAccessKey}' | base64 -d)
```
