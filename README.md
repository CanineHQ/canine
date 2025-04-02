![alt text](https://github.com/czhu12/canine/blob/main/public/images/logo-full.png?raw=true)

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
