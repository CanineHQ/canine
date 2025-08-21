set -e

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace $NAMESPACE \
  --set controller.config.use-forwarded-headers=true \
  --set controller.config.proxy-real-ip-cidr=0.0.0.0/0 \
  --set controller.config.enable-underscores-in-headers=true \
  --set controller.config.proxy-pass-headers="*" \
  --set controller.config.proxy-body-size=0 \
  --set controller.config.proxy-buffer-size=16k \
  --set controller.config.proxy-buffers-number=8 \
  --set controller.config.proxy-busy-buffers-size=32k \
  --set controller.config.proxy-read-timeout=3600 \
  --set controller.config.proxy-send-timeout=3600 \
  --set controller.config.h2-backend=true \
  --set controller.config.hsts=true \
  --set controller.config.hsts-max-age=63072000 \
  --set controller.config.hsts-include-subdomains=true \
  --set controller.config.hsts-preload=true \
  --set controller.config.enable-gzip=true \
  --set controller.config.gzip-types="text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript"
