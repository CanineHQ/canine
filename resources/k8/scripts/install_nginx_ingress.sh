set -e

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace $NAMESPACE --set controller.config.proxy-body-size=0