# From Heroku to Kubernetes (and Why It's Not That Scary)

**Speaker:** Celina Lopez
**Rough length:** ~30 minutes (adjust per section)

> Placeholders in `[brackets]` need real numbers or details from Primary.Health before the talk.

---

## 1. Intro (2 min)

- Who I am, what I do at Primary.Health
- What this talk covers:
  1. How we outgrew Heroku
  2. Why we picked Kubernetes, and what it was actually like
  3. Live demo: deploying a Rails app to Kubernetes

---

## 2. The Heroku Days (4 min)

- Primary.Health started on Heroku, like a lot of Rails shops
- Why it made sense at the start:
  - Connect to github
  - No ops team needed
  - Managed Postgres, Redis, add-ons, logs, SSL all included
  - Reliable. We didn't think about infrastructure.
  - perfect for the start

---

## 3. Then We Got Traction (4 min)

- Primary.Health started as a COVID-19 testing company, within just a few months, we got a contract with Minnesota, California, and soon would need to be in a scale where we were actively testing thousands of people everyday.
- Costs went up much faster than usage: `[$X → $Y / month over Z months]`
- **The compliance multiplier:**
  - Primary.Health is **SOC 2 compliant** and handles **PHI**
  - Handling PHI meant isolated infrastructure: on Heroku that's **Heroku Shield / Private Spaces**, which is a much more expensive tier `[$ amount]`
  - Every add-on that touches PHI also needs to be compliant, which limits your choices and raises the price

**Slide idea:** a bar or line chart of the monthly Heroku bill over time (use real numbers)

---

## 4. The Move to Kubernetes on AWS (5 min)

- What we looked at: `[e.g. staying on Heroku, plain EC2, ECS, Kubernetes]`
- What we chose: **Kubernetes on AWS on a dedicated machine** `[EKS vs. self-managed, instance type]`
  - AWS signs a BAA, and dedicated tenancy covers the isolation requirement
  - We control the network, encryption, logging, and access, which makes SOC 2 evidence easier
- **The cost difference:** `[Heroku $Y/month → AWS $Z/month, a W% reduction]`
- What we moved: web, background workers, cron jobs, `[anything else]`

**Slide idea:** a before/after cost comparison side by side

---

## 5. "Kubernetes Isn't That Bad" (4 min)

- The reputation: YAML, complexity, "you need a platform team"
- The reality: for a typical Rails app you only need **about 5 concepts**:

| Kubernetes concept     | Heroku equivalent                 |
| ---------------------- | --------------------------------- |
| **Deployment** / Pod   | Dyno (web, worker)                |
| **Service**            | Heroku's internal routing         |
| **Ingress**            | Heroku router + custom domain     |
| **Secret** / ConfigMap | Config vars (`heroku config:set`) |
| **Job** / CronJob      | Release phase / Heroku Scheduler  |

- What we learned: `[1–3 real lessons, e.g. resource limits, health checks, rollbacks]`
- **Pitch to the audience:** if you're a startup whose hosting bill is growing, or you have compliance needs, Kubernetes is worth a look before you sign a bigger PaaS contract.

---

## 6. Live Demo: Rails Todo App on Kubernetes (8 min)

### Demo setup

- A simple Rails app: ~/Desktop/simple_todo
- A local Kubernetes cluster using **k3d** (k3s running in Docker), so the demo doesn't depend on conference Wi-Fi
- Same manifests work on a real cloud cluster (EKS, DigitalOcean, Hetzner, etc.)

### Pre-talk prep (do this before going on stage)

```bash
# Tools
brew install kubectl k3d

```

App tweaks for the demo:

- `config/environments/production.rb`: set `config.force_ssl = false` and `config.assume_ssl = false` (the local demo has no TLS)
- `config/database.yml` → under `production: primary:` add `host: <%= ENV["DB_HOST"] %>`
- Rails 7.1+ already generates a production `Dockerfile` and a `/up` health check endpoint. 🎉

> Tip: pre-pull images (`postgres:16`) and run the whole demo once beforehand so the Docker build cache is warm.

---

### Step 1: Create a cluster (with a local image registry)

```bash
k3d cluster create todo \
  --registry-create todo-registry:0.0.0.0:5050 \
  -p "8080:80@loadbalancer"

kubectl get nodes
```

**Talking point:** "That's a real Kubernetes cluster. In production, this would be EKS or a VM running k3s."

---

### Step 2: Build and push the Docker image

```bash
docker build -t localhost:5050/todo:v1 .
docker push localhost:5050/todo:v1
```

**Talking point:** "The Dockerfile came free with `rails new`. This replaces Heroku's buildpack step."

---

### Step 3: Create a namespace and secrets (like `heroku config:set`)

```bash
kubectl create namespace todo

kubectl -n todo create secret generic todo-secrets \
  --from-literal=RAILS_MASTER_KEY=$(cat config/master.key) \
  --from-literal=TODO_DATABASE_PASSWORD=supersecret
```

---

### Step 4: The manifest

The manifests live in the `k8s/` folder, one file per concern (this is the "scary YAML" moment, but each file is small):

| File                  | Kind                  | Heroku equivalent            |
| --------------------- | --------------------- | ---------------------------- |
| `k8s/namespace.yaml`  | Namespace             | App / project                |
| `k8s/storage.yaml`    | PersistentVolumeClaim | Disk for the SQLite database |
| `k8s/deployment.yaml` | Deployment            | Dyno                         |
| `k8s/service.yaml`    | Service               | Internal routing             |
| `k8s/ingress.yaml`    | Ingress               | Router / domain              |

Secrets (`RAILS_MASTER_KEY`) are created with `kubectl`, not stored in a file (see Step 5).

**Talking point:** walk through each file using the concept table from Section 5. Deployment = dyno, Service = routing, Ingress = router/domain, Secret = config vars.

> The Rails Dockerfile's `CMD` runs `db:prepare` on boot, so the database is created and migrated automatically. On a bigger app, run migrations as a separate Kubernetes `Job` (that's the "release phase" equivalent).

> This app uses SQLite, so the Deployment runs a single replica on a persistent volume. To scale out, move to a managed database (e.g. Postgres/RDS) first.

---

### Step 5: Deploy

Apply the files in this order, since later ones depend on earlier ones.

**1. Namespace** (everything else lives in it)

```bash
kubectl apply -f k8s/namespace.yaml
kubectl get namespace todo
```

**2. Secret** (Rails master key, like Heroku config vars)

```bash
kubectl -n todo create secret generic todo-secrets \
  --from-file=RAILS_MASTER_KEY=config/master.key
kubectl -n todo get secret todo-secrets
```

**3. Storage** (volume for the SQLite database)

```bash
kubectl apply -f k8s/storage.yaml
kubectl -n todo get pvc
```

**4. Deployment** (the Rails pods)

```bash
kubectl apply -f k8s/deployment.yaml
kubectl -n todo get pods -w           # watch pods start up
kubectl -n todo logs deploy/todo-web  # tail Rails logs (like `heroku logs`)
```

**5. Service** (stable internal address for the pods)

```bash
kubectl apply -f k8s/service.yaml
kubectl -n todo get service todo-web
```

**6. Ingress** (expose it outside the cluster)

```bash
kubectl apply -f k8s/ingress.yaml
kubectl -n todo get ingress todo-web
```

**Or apply everything at once** (the secret still needs step 2 first):

```bash
kubectl apply -f k8s/
```

**Tear down**

```bash
kubectl delete namespace todo   # removes everything above, including the volume
```

Open **http://localhost:8080**, create a couple of todos. ✅

---

### Step 6: The "Heroku features" lightning round (# PROBABLY WOULD SKIP THIS)

```bash
# Scale (like `heroku ps:scale web=4`)
kubectl -n todo scale deploy/todo-web --replicas=4
kubectl -n todo get pods

# Rails console (like `heroku run rails c`)
kubectl -n todo exec -it deploy/todo-web -- bin/rails console

# Ship a new version
docker build -t localhost:5050/todo:v2 . && docker push localhost:5050/todo:v2
kubectl -n todo set image deploy/todo-web web=todo-registry:5050/todo:v2
kubectl -n todo rollout status deploy/todo-web

# Oops, roll back (like `heroku rollback`)
kubectl -n todo rollout undo deploy/todo-web
```

**Talking point:** "Zero-downtime rolling deploys, scaling, and rollbacks come built in."

### Cleanup (after the talk)

```bash
k3d cluster delete todo
```

---

## 7. "But That Was a Lot of Commands..." (1 min)

- Be honest: it works, but it's a lot to remember
  - You still need CI to build images, a way to manage YAML for every app, a way to handle domains and SSL, and something that lets your team deploy without `kubectl` access
- This is the part Heroku did well: **the developer experience**
- So what if you could keep the Kubernetes cost savings **and** get the Heroku experience back?

---

## 8. Introducing Canine (3 min)

**Canine: an open source, developer-friendly PaaS for your own Kubernetes cluster**

- Apache 2.0 licensed: https://github.com/CanineHQ/canine
- Built with Rails 🚂 (Hotwire, GoodJob, PostgreSQL), so this audience can contribute

### What it does

| Feature                                          | What it replaces from the demo                   |
| ------------------------------------------------ | ------------------------------------------------ |
| Git-driven deploys (GitHub/GitLab webhooks)      | `docker build` / `push` / `set image`            |
| Built-in image builds (Dockerfile or buildpacks) | Manual Docker builds and CI pipelines            |
| Web services, workers, and cron jobs             | Hand-written Deployments and CronJobs            |
| Environment variables and secrets UI             | `kubectl create secret`                          |
| Custom domains, DNS integration, automatic SSL   | Ingress YAML and cert-manager setup              |
| CPU, memory, and GPU limits                      | `resources:` blocks                              |
| Persistent volumes                               | PVC YAML                                         |
| Teams, multi-tenancy, SSO (SAML/OIDC/LDAP)       | Handing out kubeconfigs                          |
| Custom pod templates                             | An escape hatch for when you need raw Kubernetes |

### Get it running

```bash
curl -sSL https://canine.sh/install.sh | bash
# or
git clone https://github.com/CanineHQ/canine.git && cd canine
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > .env
docker compose up -d
# → http://localhost:3000
```

### Mini demo / screenshots: the same todo app, using Canine

1. Add a cluster (paste or upload the kubeconfig)
2. Create a project → connect the `todo` GitHub repo
3. Add a web service and set the env vars (`RAILS_MASTER_KEY`, etc.)
4. Add a domain → SSL is handled automatically
5. `git push` → watch the build and deploy logs in the UI
6. Scale, view logs, and roll back from the dashboard

**Talking point:** "Everything from the last 8 minutes of commands, done in a few clicks, on infrastructure you own and at Kubernetes prices."

### Options

- **Self-hosted:** free and open source
- **Canine Cloud:** managed version for small teams, https://canine.sh

---

## 9. Wrap Up (1 min)

- Heroku is a great place to start, but watch the bill as you grow, especially if you have compliance needs
- Kubernetes is more approachable than its reputation suggests. A Rails app needs about 5 concepts.
- If you want the savings without the YAML, try Canine. ⭐ Star it, try it, and open PRs.
- Links:
  - GitHub: https://github.com/CanineHQ/canine
  - Docs: https://docs.canine.sh
  - `[your contact / socials]`

**Q&A**
