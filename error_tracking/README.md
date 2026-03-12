# Error Tracking

Lightweight, self-hosted Sentry-compatible error tracking service. Runs inside Kubernetes clusters and accepts errors from any app using a standard Sentry SDK.

Built in Rust with SQLite storage. No authentication required — designed for private, cluster-internal use.

## Quick Start

```bash
# Build
cargo build --release

# Run (defaults to port 3001, SQLite at data/errors.db)
./target/release/error-tracking

# Or configure with env vars
PORT=8080 DATABASE_PATH=/var/lib/errors/db.sqlite ./target/release/error-tracking
```

## Deploy to Kubernetes

```bash
# Build and push the Docker image
docker build -t your-registry/error-tracking:latest .
docker push your-registry/error-tracking:latest

# Install via Helm
helm install error-tracking ./helm \
  --set image.repository=your-registry/error-tracking \
  --set image.tag=latest
```

Or install as a cluster package from Canine's cluster settings UI.

## Usage

### 1. Create a source

```bash
curl -X POST http://error-tracking:3001/api/sources \
  -H "Content-Type: application/json" \
  -d '{"name": "my-app", "platform": "ruby"}'
```

Returns:
```json
{"id": 1, "name": "my-app", "platform": "ruby", "public_key": "a1b2c3..."}
```

Sources can also be created from the Canine UI via the Errors tab on a cluster.

### 2. Configure your app

Set your Sentry DSN to point at the service:

```
SENTRY_DSN=http://<public_key>@error-tracking.<namespace>.svc.cluster.local:3001/api/1
```

Works with any standard Sentry SDK — Ruby, Python, JavaScript, Go, etc.

### 3. View errors

- **Canine UI**: Set the error tracking URL in your cluster settings, then use the Errors tab
- **Web UI**: `http://error-tracking:3001/`
- **API**: `GET /api/sources/:id/events`

## API

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/sources` | Create a source |
| `GET` | `/api/sources` | List all sources |
| `GET` | `/api/sources/:id/events` | List events for a source |
| `POST` | `/api/:source_id/store/` | Sentry store endpoint |
| `POST` | `/api/:source_id/envelope/` | Sentry envelope endpoint |

## Configuration

| Env Var | Default | Description |
|---------|---------|-------------|
| `PORT` | `3001` | HTTP listen port |
| `DATABASE_PATH` | `data/errors.db` | SQLite database file path |
