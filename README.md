<br/>
<div align="center">
<a href="https://github.com/CanineHQ/canine">
<img src="https://github.com/CanineHQ/canine/blob/main/public/images/logo-full.webp?raw=true" alt="Logo" height="100">
</a>
<h3 align="center">Canine</h3>
<p align="center">
A developer-friendly PaaS for your Kubernetes
<br/>
<br/>
<a href="https://docs.canine.sh"><strong>Explore the docs »</strong></a>
<br/>
<br/>
<a href="https://canine.sh">View Demo .</a>  
<a href="https://github.com/CanineHQ/canine/issues/new?labels=bug">Report Bug .</a>
<a href="https://github.com/CanineHQ/canine/issues/new?labels=enhancement">Request Feature</a>
</p>
</div>

[![Build Status](https://github.com/CanineHQ/canine/actions/workflows/ci.yml/badge.svg)](https://github.com/CanineHQ/canine/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache-blue.svg)](https://opensource.org/licenses/Apache)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/canine)](https://artifacthub.io/packages/search?repo=canine)


![Deployment Screenshot](https://raw.githubusercontent.com/CanineHQ/canine/refs/heads/main/public/images/deployment_styled.webp)

## About the project

Canine is a self-hosted Kubernetes deployment platform that brings the simplicity of Platform-as-a-Service (like Heroku) to your own Kubernetes infrastructure. Deploy applications with git push, manage services through an intuitive web interface, and leverage the full power of Kubernetes without writing YAML.

### Why Canine?

**Kubernetes Made Simple**
Stop wrestling with kubectl and complex YAML manifests. Canine provides a clean web interface to deploy, scale, and manage your applications on Kubernetes.

**Git-Driven Deployments**
Connect your GitHub or GitLab repository and deploy automatically on every push. Canine builds your Docker images and handles the entire deployment pipeline.

**Full Kubernetes Control**
Unlike hosted PaaS solutions, you maintain complete control over your infrastructure. Run Canine on any Kubernetes cluster - cloud, on-premise, or edge.

### Core Features

| Feature | Description |
|---------|-------------|
| **🚀 Automated Deployments** | Git webhook integration for continuous deployment from GitHub/GitLab |
| **🐳 Built-in Image Building** | Automatic Docker image builds using Dockerfile or buildpacks |
| **🔧 Service Management** | Deploy web services, background workers, and scheduled cron jobs |
| **📊 Resource Constraints** | Configure CPU, memory, and GPU limits for your applications |
| **🌐 Domain & SSL** | Custom domain management with DNS integration and automatic SSL |
| **🔐 Secrets & Config** | Environment variables and Kubernetes secrets management |
| **💾 Persistent Storage** | Volume management for stateful applications and databases |
| **👥 Multi-tenancy** | Account-based isolation with team collaboration and access control |
| **⚙️ Custom Pod Templates** | Advanced Kubernetes pod customization with YAML configuration |
| **🔑 Enterprise SSO** | Single sign-on support with SAML, OIDC, and LDAP integration |

## Requirements

* Docker v24.0.0 or higher
* Docker Compose v2.0.0 or higher

## Installation
```bash
curl -sSL https://raw.githubusercontent.com/CanineHQ/canine/refs/heads/main/install/install.sh | bash
```
---

Or run manually if you prefer:
```bash
git clone https://github.com/CanineHQ/canine.git
cd canine/install
docker compose up -d
```
and open http://localhost:3000 in a browser.

To customize the web ui port, supply the PORT env var when running docker compose:
```bash
PORT=3456 docker compose up -d
```

## Cloud

Canine Cloud offers additional features for small teams:
- GitHub integration for seamless deployment workflows
- Team collaboration with role-based access control
- Real-time metric tracking and monitoring
- Way less maintenance for you

For more information & pricing, take a look at our landing page [https://canine.sh](https://canine.sh).

## License

Canine is released under the [Apache 2.0 License](https://github.com/CanineHQ/canine/blob/main/LICENSE).

You are free to use, modify, and distribute this software for commercial and non-commercial purposes. See the LICENSE file for full details.

For commercial support, enterprise features, or managed hosting, visit [https://canine.sh](https://canine.sh).
