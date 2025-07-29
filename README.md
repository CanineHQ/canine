<br/>
<div align="center">
<a href="https://github.com/czhu12/canine">
<img src="https://github.com/czhu12/canine/blob/main/public/images/logo-full.png?raw=true" alt="Logo" height="100">
</a>
<h3 align="center">Canine</h3>
<p align="center">
Power of Kubernetes, Simplicity of Heroku
<br/>
<br/>
<a href="https://docs.canine.sh"><strong>Explore the docs »</strong></a>
<br/>
<br/>
<a href="https://canine.sh">View Demo .</a>  
<a href="https://github.com/czhu12/canine/issues/new?labels=bug">Report Bug .</a>
<a href="https://github.com/czhu12/canine/issues/new?labels=enhancement">Request Feature</a>
</p>
</div>

[![Build Status](https://github.com/czhu12/canine/actions/workflows/ci.yml/badge.svg)](https://github.com/czhu12/canine/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache-blue.svg)](https://opensource.org/licenses/Apache)


![Deployment Screenshot](https://raw.githubusercontent.com/czhu12/canine/refs/heads/main/public/images/deployment_styled.png)

## About the project
Canine is an easy to use intuitive deployment platform for Kubernetes clusters.

## Requirements

* Docker v24.0.0 or higher
* Docker Compose v2.0.0 or higher

## Installation
```bash
curl -sSL https://raw.githubusercontent.com/czhu12/canine/refs/heads/main/install/install.sh | bash
```
---

Or run manually if you prefer:
```bash
git clone https://github.com/czhu12/canine.git
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

## Repo Activity
![Alt](https://repobeats.axiom.co/api/embed/0af4ce8a75f4a12ec78973ddf7021c769b9a0051.svg "Repobeats analytics image")

## License

[Apache 2.0 License](https://github.com/czhu12/canine/blob/main/LICENSE)
