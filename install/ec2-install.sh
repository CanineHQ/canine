#!/bin/bash
# Installs or upgrades Canine on a Linux server (e.g. an EC2 box) with Docker Compose.
#
#   curl -sSL https://raw.githubusercontent.com/CanineHQ/canine/main/install/ec2-install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/CanineHQ/canine/main/install/ec2-install.sh | bash -s -- --host https://canine.example.ts.net
#
# Canine listens on 127.0.0.1 only; reach it through Tailscale, a Cloudflare Tunnel or an SSH tunnel.
# Re-running upgrades in place and keeps .env (including SECRET_KEY_BASE) and the database.
set -euo pipefail

CANINE_HOME="${CANINE_HOME:-$HOME/.canine}"
CANINE_REF="${CANINE_REF:-main}"
RAW_URL="https://raw.githubusercontent.com/CanineHQ/canine/${CANINE_REF}"
INSTALL_URL="$RAW_URL/install/ec2-install.sh"
HEALTH_TIMEOUT=300

usage() {
  cat <<EOF
Usage: install.sh [--host URL] [--port PORT] [--bind ADDRESS]

  --host URL       Public URL people use to reach Canine, e.g. https://canine.example.ts.net (sets APP_HOST)
  --port PORT      Port Canine listens on (default: 3000)
  --bind ADDRESS   Address the port is published on (default: 127.0.0.1; 0.0.0.0 exposes it on every interface)
EOF
}

APP_HOST_ARG=""
PORT_ARG=""
BIND_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --host) APP_HOST_ARG="${2:?--host needs a value}"; shift 2 ;;
    --port) PORT_ARG="${2:?--port needs a value}"; shift 2 ;;
    --bind) BIND_ARG="${2:?--bind needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

ok() { echo " [OK]${1:+ $1}"; }
fail() { echo " [FAIL]"; echo "$1" >&2; exit 1; }

cat << "EOF"
   _____            _
  / ____|          (_)
 | |     __ _ _ __  _ _ __   ___
 | |    / _` | '_ \| | '_ \ / _ \
 | |___| (_| | | | | | | | |  __/
  \_____\__,_|_| |_|_|_| |_|\___|
EOF
echo

echo -n "Checking required tools..."
for tool in curl openssl docker; do
  command -v "$tool" > /dev/null 2>&1 || fail "$tool is not installed. Install Docker (https://docs.docker.com/engine/install/), curl and openssl, then re-run."
done
docker compose version > /dev/null 2>&1 || fail "The Docker Compose plugin is not installed: https://docs.docker.com/compose/install/linux/"
ok

echo -n "Checking Docker access..."
docker info > /dev/null 2>&1 || fail "Can't talk to the Docker daemon. Make sure it's running, then either add yourself to the docker group
(sudo usermod -aG docker \$USER, then log out and back in) or re-run this script with sudo."
DOCKER_SOCKET="/var/run/docker.sock"
if [[ "${DOCKER_HOST:-}" == unix://* ]]; then
  DOCKER_SOCKET="${DOCKER_HOST#unix://}"
fi
[ -S "$DOCKER_SOCKET" ] || fail "Docker socket not found at $DOCKER_SOCKET. Set DOCKER_HOST=unix:///path/to/docker.sock and re-run."
ok "($DOCKER_SOCKET)"

mkdir -p "$CANINE_HOME"
cd "$CANINE_HOME"
touch .env
chmod 600 .env

env_get() { grep -E "^$1=" .env | tail -n 1 | cut -d= -f2- || true; }
env_set() {
  local tmp
  tmp=$(mktemp)
  grep -vE "^$1=" .env > "$tmp" || true
  echo "$1=$2" >> "$tmp"
  mv "$tmp" .env
  chmod 600 .env
}

echo -n "Writing configuration..."
[ -n "$(env_get COMPOSE_PROJECT_NAME)" ] || env_set COMPOSE_PROJECT_NAME canine
[ -n "$(env_get SECRET_KEY_BASE)" ] || env_set SECRET_KEY_BASE "$(openssl rand -hex 64)"
if [ -n "$PORT_ARG" ] || [ -z "$(env_get PORT)" ]; then env_set PORT "${PORT_ARG:-3000}"; fi
if [ -n "$BIND_ARG" ] || [ -z "$(env_get BIND_ADDRESS)" ]; then env_set BIND_ADDRESS "${BIND_ARG:-127.0.0.1}"; fi
if [ -n "$APP_HOST_ARG" ] || [ -z "$(env_get APP_HOST)" ]; then env_set APP_HOST "${APP_HOST_ARG:-http://localhost:$(env_get PORT)}"; fi
env_set DOCKER_SOCKET "$DOCKER_SOCKET"
PORT=$(env_get PORT)
BIND_ADDRESS=$(env_get BIND_ADDRESS)
APP_HOST=$(env_get APP_HOST)
ok "($CANINE_HOME/.env)"

echo -n "Downloading Canine ($CANINE_REF)..."
curl -fsSL "$RAW_URL/docker-compose.yml" -o docker-compose.yml.new || fail "Couldn't download $RAW_URL/docker-compose.yml"
mv docker-compose.yml.new docker-compose.yml
ok

# The helper upgrades by re-running this installer, which keeps .env and the database
cat > canine <<HELPER
#!/bin/bash
# Manages the Canine install in $CANINE_HOME. Settings live in $CANINE_HOME/.env.
set -euo pipefail
cd "$CANINE_HOME"

case "\${1:-}" in
  start) docker compose up -d ;;
  stop) docker compose stop ;;
  restart) docker compose up -d --force-recreate web worker ;;
  status) docker compose ps ;;
  logs) shift; docker compose logs -f --tail 100 "\$@" ;;
  upgrade) curl -fsSL "$INSTALL_URL" | CANINE_HOME="$CANINE_HOME" CANINE_REF="$CANINE_REF" bash ;;
  uninstall)
    read -r -p "This deletes Canine's database and $CANINE_HOME. Type 'delete' to continue: " answer
    [ "\$answer" = "delete" ] || { echo "Aborted"; exit 1; }
    docker compose down --volumes --rmi all
    rm -rf "$CANINE_HOME"
    ;;
  *)
    echo "Usage: canine start | stop | restart | status | logs [service] | upgrade | uninstall"
    exit 1
    ;;
esac
HELPER
chmod +x canine

echo "Pulling images..."
docker compose pull < /dev/null
echo "Starting Canine..."
docker compose up -d --remove-orphans < /dev/null

echo -n "Waiting for Canine to be ready..."
health_host="$BIND_ADDRESS"
[ "$health_host" = "0.0.0.0" ] && health_host="127.0.0.1"
deadline=$((SECONDS + HEALTH_TIMEOUT))
until curl -fsS "http://$health_host:$PORT/up" > /dev/null 2>&1; do
  if [ $SECONDS -ge $deadline ]; then
    echo " [FAIL]"
    docker compose logs --tail 50 web
    echo "Canine didn't come up within ${HEALTH_TIMEOUT}s. See the logs above, or run: $CANINE_HOME/canine logs" >&2
    exit 1
  fi
  echo -n "."
  sleep 3
done
ok

# Put the helper on the PATH where we can without prompting
helper_dir=""
if [ -w /usr/local/bin ]; then
  helper_dir=/usr/local/bin
elif sudo -n true 2> /dev/null; then
  sudo ln -sf "$CANINE_HOME/canine" /usr/local/bin/canine && helper_dir=/usr/local/bin
fi
if [ -z "$helper_dir" ]; then
  mkdir -p "$HOME/.local/bin"
  helper_dir="$HOME/.local/bin"
fi
[ -e "$helper_dir/canine" ] || ln -sf "$CANINE_HOME/canine" "$helper_dir/canine"

cat <<EOF

Canine is running on http://$health_host:$PORT (published on $BIND_ADDRESS only).

Next steps:
  1. Expose it to your team privately, e.g. with Tailscale:
       sudo tailscale serve --bg $PORT
  2. Point APP_HOST at the URL people will use (currently $APP_HOST):
       curl -sSL $INSTALL_URL | bash -s -- --host https://<your-host>
  3. Open it and create the first account right away; the first visitor sets up the instance.

Manage it with 'canine' (in $helper_dir): canine status | logs | restart | upgrade | stop
EOF
