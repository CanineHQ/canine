# Canine Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/canine)](https://artifacthub.io/packages/search?repo=canine)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Overview

This Helm chart deploys [Canine](https://github.com/czhu12/canine) - a Rails-based Kubernetes deployment platform that provides an intuitive web interface for managing applications on Kubernetes clusters.

Canine simplifies application deployment to Kubernetes with features including:
- **Git Integration**: Connect to GitHub/GitLab repositories for automated deployments
- **Docker Registry Support**: Works with Docker Hub, GitHub Container Registry, and more
- **Multi-cluster Management**: Deploy to multiple Kubernetes clusters from a single interface
- **CI/CD Pipeline**: Built-in build and deployment pipelines
- **Environment Management**: Manage multiple environments (dev, staging, production)
- **DNS Management**: Automatic DNS configuration with Cloudflare integration

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for PostgreSQL persistence)
- (Optional) Ingress controller for external access

## Installation

### Quick Start

#### From Artifact Hub

```bash
# Add the Canine Helm repository
helm repo add canine https://czhu12.github.io/canine
helm repo update

# Install Canine
helm install canine canine/canine --namespace canine --create-namespace
```

#### From Source

```bash
# Clone the repository
git clone https://github.com/czhu12/canine.git
cd canine/helm/canine

# Add Bitnami repository (for PostgreSQL dependency)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install dependencies
helm dependency update

# Install the chart
helm install canine . --namespace canine --create-namespace
```

### Install with custom values

```bash
# Create a custom values file
cat > custom-values.yaml <<EOF
canine:
  auth:
    username: myadmin
    password: mysecurepassword
  secretKeyBase: "your-secure-secret-key-base"

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: canine.example.com
      paths:
        - path: /
          pathType: Prefix
EOF

# Install with custom values
helm install canine canine/canine \
  --namespace canine \
  --create-namespace \
  -f custom-values.yaml
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

### Worker Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.enabled` | Enable background worker | `true` |
| `worker.replicaCount` | Number of worker replicas | `1` |
| `worker.maxThreads` | Maximum worker threads | `5` |
| `worker.queues` | Job queues to process | `*` |

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

## Production Considerations

### Security

1. **Change Default Credentials**: Always change the default admin username and password
2. **Secret Key Base**: Generate a secure SECRET_KEY_BASE for production:
   ```bash
   openssl rand -hex 64
   ```
3. **Database Passwords**: Use strong passwords for PostgreSQL
4. **TLS/SSL**: Enable ingress with TLS certificates for production deployments

### High Availability

For production deployments, consider:
- Increasing `replicaCount` for the application
- Enabling PostgreSQL replication
- Using external managed databases (RDS, Cloud SQL, etc.)
- Configuring pod anti-affinity rules

### Resource Requirements

Recommended minimum resources for production:
- Canine application: 1 CPU, 1Gi memory
- PostgreSQL: 1 CPU, 2Gi memory
- Worker: 0.5 CPU, 512Mi memory

## Troubleshooting

### Database Connection Issues

If the application can't connect to PostgreSQL:
```bash
# Check PostgreSQL pod status
kubectl get pods -n canine -l app.kubernetes.io/name=postgresql

# View application logs
kubectl logs -n canine -l app.kubernetes.io/name=canine
```

### Worker Not Processing Jobs

Check worker pod logs:
```bash
kubectl logs -n canine -l app.kubernetes.io/component=worker
```

## Support

- **Documentation**: [GitHub Wiki](https://github.com/czhu12/canine/wiki)
- **Issues**: [GitHub Issues](https://github.com/czhu12/canine/issues)
- **Discussions**: [GitHub Discussions](https://github.com/czhu12/canine/discussions)

## License

This Helm chart is licensed under the MIT License. See the [LICENSE](https://github.com/czhu12/canine/blob/main/LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.