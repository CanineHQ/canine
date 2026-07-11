# Canine Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/canine)](https://artifacthub.io/packages/search?repo=canine)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Overview

This Helm chart deploys [Canine](https://github.com/czhu12/canine) - a modern, open source alternative to Heroku. Canine provides an intuitive web interface for managing application deployments on Kubernetes clusters.

> **New to self-hosting Canine?** Follow the [step-by-step cluster mode tutorial](https://docs.canine.sh/docs/self-hosted/cluster-mode) to get up and running.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for PostgreSQL persistence)

## Installation

### Add the Helm Repository

```bash
helm repo add canine https://caninehq.github.io/canine
helm repo update
```

### Option 1: With a Domain Name (Recommended)

This installs Canine with Traefik ingress, cert-manager for automatic TLS, and a custom domain.

```bash
helm install canine canine/canine \
  --namespace canine \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hostname=canine.example.com \
  --set canine.acmeEmail=you@example.com
```

#### DNS Setup

After installation, get the external IP of the load balancer:

```bash
kubectl get svc -n canine -l "app.kubernetes.io/name=traefik" \
  -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}"
```

Some cloud providers assign a hostname instead of an IP:

```bash
kubectl get svc -n canine -l "app.kubernetes.io/name=traefik" \
  -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}"
```

Then create a DNS record:

| Type | Name | Value |
|------|------|-------|
| A | canine.example.com | `<IP from above>` |

Or if your provider gave a hostname:

| Type | Name | Value |
|------|------|-------|
| CNAME | canine.example.com | `<hostname from above>` |

Once DNS propagates, cert-manager will automatically issue a Let's Encrypt TLS certificate. Your site will be live at `https://canine.example.com`.

#### Already have cert-manager or an ingress controller?

If your cluster already has these installed, disable them to avoid conflicts:

```bash
helm install canine canine/canine \
  --namespace canine \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hostname=canine.example.com \
  --set ingress.className=your-existing-ingress-class \
  --set canine.acmeEmail=you@example.com \
  --set cert-manager.enabled=false \
  --set traefik.enabled=false
```

### Option 2: Without a Domain (Local / Port-Forward)

This is the simplest setup — no ingress, no TLS, just access via port-forward.

```bash
helm install canine canine/canine \
  --namespace canine \
  --create-namespace \
  --set ingress.enabled=false \
  --set cert-manager.enabled=false \
  --set traefik.enabled=false
```

Access Canine via port-forward:

```bash
kubectl port-forward -n canine svc/canine 3000:3000
```

Then open http://localhost:3000.

## Configuration

### Canine Application

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of web replicas | `1` |
| `image.repository` | Image repository | `ghcr.io/caninehq/canine` |
| `image.tag` | Image tag | `latest` |
| `canine.port` | Application port | `3000` |
| `canine.bootMode` | Boot mode | `cluster` |
| `canine.secretKeyBase` | Rails secret key base | `<default>` |
| `canine.allowedHostname` | Allowed hostnames for Rails | `*` |
| `canine.acmeEmail` | Email for Let's Encrypt | `admin@example.com` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `traefik` |
| `ingress.hosts[0].host` | Hostname | `canine.example.com` |
| `ingress.tls[0].secretName` | TLS secret name | `canine-tls` |

### Worker

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.enabled` | Enable background worker | `true` |
| `worker.replicaCount` | Number of worker replicas | `1` |
| `worker.maxThreads` | Maximum worker threads | `5` |

### PostgreSQL (Bitnami)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.auth.username` | Username | `postgres` |
| `postgresql.auth.password` | Password | `password` |
| `postgresql.auth.database` | Database name | `canine_production` |
| `postgresql.primary.persistence.size` | PVC size | `8Gi` |

### Cert Manager (Jetstack)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cert-manager.enabled` | Enable cert-manager | `true` |
| `cert-manager.crds.enabled` | Install CRDs | `true` |

### Traefik Ingress Controller

| Parameter | Description | Default |
|-----------|-------------|---------|
| `traefik.enabled` | Enable Traefik | `true` |
| `traefik.ingressClass.name` | IngressClass name | `traefik` |

## Uninstalling

```bash
helm uninstall canine --namespace canine
```

## Troubleshooting

### Pods not starting

```bash
kubectl get pods -n canine
kubectl describe pod -n canine -l app.kubernetes.io/name=canine
```

### Database connection issues

The web pod will crash-loop until PostgreSQL is ready. This is normal on first install — it will recover automatically.

### Certificate not issuing

Check the certificate and challenge status:

```bash
kubectl get certificate -n canine
kubectl describe challenge -n canine
```

Common issues:
- DNS not pointing to the load balancer IP yet
- cert-manager can't resolve the domain from inside the cluster (the chart configures public DNS resolvers by default)

## License

MIT License. See [LICENSE](https://github.com/czhu12/canine/blob/main/LICENSE).
