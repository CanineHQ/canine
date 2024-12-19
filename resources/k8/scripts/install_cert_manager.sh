set -e

helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace $NAMESPACE \
  --create-namespace \
  --version v1.15.3 \
  --set crds.enabled=true