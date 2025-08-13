# Canine Helm Chart

This Helm chart deploys Canine - a Rails-based Kubernetes deployment platform.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for PostgreSQL and Redis persistence)

## Installation

### Add Bitnami repository (for PostgreSQL and Redis dependencies)

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Install the chart

```bash
# From the helm/canine directory
helm dependency update
helm install canine . --namespace canine --create-namespace
```

### Install with custom values

```bash
helm install canine . --namespace canine --create-namespace -f custom-values.yaml
```

## Configuration

The following table lists the configurable parameters and their default values:

### Canine Application

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Canine image repository | `czhu12/canine` |
| `image.tag` | Canine image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `canine.port` | Application port | `3000` |
| `canine.localMode` | Enable local mode | `true` |
| `canine.appHost` | Application host URL | `http://localhost:3000` |
| `canine.secretKeyBase` | Rails secret key base | `<generated>` |
| `canine.auth.username` | Admin username | `admin` |
| `canine.auth.password` | Admin password | `changeme` |
| `canine.mountDockerSocket` | Mount Docker socket | `true` |
| `canine.dockerSocketPath` | Docker socket path | `/var/run/docker.sock` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `3000` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts[0].host` | Hostname | `canine.local` |

### PostgreSQL (Bitnami)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.auth.username` | PostgreSQL username | `postgres` |
| `postgresql.auth.password` | PostgreSQL password | `password` |
| `postgresql.auth.database` | PostgreSQL database | `canine_production` |
| `postgresql.primary.persistence.size` | PVC size | `8Gi` |

### Redis (Bitnami)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.enabled` | Enable Redis | `true` |
| `redis.architecture` | Redis architecture | `standalone` |
| `redis.auth.enabled` | Enable Redis auth | `false` |
| `redis.master.persistence.size` | PVC size | `2Gi` |

## Uninstalling the Chart

```bash
helm uninstall canine --namespace canine
```

## Upgrading the Chart

```bash
helm upgrade canine . --namespace canine
```

## Development

To use a local Docker image:

1. Build your Docker image locally
2. Update the values:
```yaml
image:
  repository: canine
  tag: dev
  pullPolicy: Never
```

## Notes

- The chart includes Bitnami's PostgreSQL and Redis as dependencies
- Docker socket mounting is enabled by default for local mode operations
- Persistence is enabled for both PostgreSQL and Redis by default
- The SECRET_KEY_BASE should be changed in production deployments