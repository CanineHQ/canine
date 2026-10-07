# Langfuse for agent sessions (local)

Canine sends everything that goes in and out of an agent session to Langfuse, so it can be browsed and improved:

- every call to OpenRouter, for the model's turns and Jev's decisions: the full request, the full response, tokens
  and cost;
- every request to the computer-use server in the VM, with its exact body and reply. Screenshots show as images.

Each job is one trace (`turn 7`, `tidy`, `wrap-up`), grouped by the agent session (`agent-session-<id>`). Langfuse's
**Sessions** view shows a session's turns in order. The code is `app/services/agent_loop/trace.rb`.

Tracing is optional. It's on only when Canine has these three variables set, and spans are sent in the background:
a slow or missing Langfuse never slows down or breaks a session.

```
LANGFUSE_HOST=http://localhost:3100
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
```

## Running it

```
cd dev/langfuse
docker compose up -d        # http://localhost:3100
docker compose down         # stop (data is kept in Docker volumes; add -v to delete it)
```

- **First start:** run `./setup` once. It generates `.env` (secrets, the project's API keys and a login; git-ignored)
  and prints the three lines to add to Canine's `.env`. On first `up`, Langfuse creates the project ("Canine agents")
  and the login from it.
- **Logging in:** use `LANGFUSE_INIT_USER_EMAIL` and `LANGFUSE_INIT_USER_PASSWORD` from `.env`.
- **Canine's own `.env`** has the three `LANGFUSE_*` variables above. Restart the GoodJob worker after changing them.

`docker-compose.yml` is Langfuse's official file, unchanged. `docker-compose.override.yml` changes two things:

- **Ports:** it moves the web UI to 3100, Postgres to 5433 and Redis to 6380, off the ones Canine uses.
- **Storage:** it replaces the S3 store. Langfuse's MinIO image crashes with "illegal instruction" under Docker
  Desktop on Apple silicon, and MinIO no longer publishes public images, so SeaweedFS's S3 server stands in. It
  checks no access keys, so it's for local use only.

## Production

- **Deploy:** use Langfuse's Helm chart (https://langfuse.com/self-hosting), which brings web, worker, Postgres,
  ClickHouse, Redis and S3 storage.
- **Configure Canine:** set the three variables in its environment.
- **Retention:** traces contain people's emails, messages and screenshots, so set a data retention period in the
  project settings and restrict who can log in.
- **Cost:** self-hosting is free. Only a few enterprise add-ons need a license key.
