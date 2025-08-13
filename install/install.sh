#!/bin/bash
set -e

# Add ASCII art at the beginning
cat << "EOF"
   _____            _            
  / ____|          (_)           
 | |     __ _ _ __  _ _ __   ___ 
 | |    / _` | '_ \| | '_ \ / _ \
 | |___| (_| | | | | | | | |  __/
  \_____\__,_|_| |_|_|_| |_|\___|
EOF
echo

echo -n "Cloning Canine..."
mkdir -p ~/.canine
# Remove existing src directory if it exists
rm -rf ~/.canine/src
# Shallow clone the repo
git clone --depth 1 https://github.com/czhu12/canine.git ~/.canine/src

cd ~/.canine/src
echo " [OK]"

echo -n "Checking Docker..."
# Function to check if a socket file exists and is accessible
check_docker_socket() {
    local socket_path="$1"
    if [ -S "$socket_path" ] && [ -w "$socket_path" ]; then
        echo "$socket_path"
        return 0
    fi
    return 1
}

# Try to find Docker socket in common locations
DOCKER_SOCKET=""
for socket in "/var/run/docker.sock" "/run/docker.sock" "$HOME/.docker/run/docker.sock"; do
    if check_docker_socket "$socket"; then
        DOCKER_SOCKET="$socket"
        break
    fi
done

# If no socket found, try to get it from Docker's configuration
if [ -z "$DOCKER_SOCKET" ]; then
    if command -v docker >/dev/null 2>&1; then
        # Try to get socket from docker info
        DOCKER_SOCKET=$(docker info --format '{{.DockerRootDir}}/docker.sock' 2>/dev/null)
        if [ -n "$DOCKER_SOCKET" ] && check_docker_socket "$DOCKER_SOCKET"; then
            :  # Found valid socket from Docker info
        else
            # Try to get socket from docker context
            DOCKER_SOCKET=$(docker context inspect | grep -o '"Host": *"unix://[^"]*"' | head -n 1 | sed -E 's/.*"unix:\/\/(.*)"$/\1/')
            if [ -n "$DOCKER_SOCKET" ] && check_docker_socket "$DOCKER_SOCKET"; then
                :  # Found valid socket from Docker context
            else
                DOCKER_SOCKET=""
            fi
        fi
    fi
fi

if [ -z "$DOCKER_SOCKET" ]; then
    echo " [FAIL]"
    echo "Docker socket not found. Please ensure:"
    echo "1. Docker is installed and running"
    echo "2. You have permissions to access the Docker socket"
    echo "3. Docker is configured correctly"
    echo "Common socket locations checked:"
    echo "- /var/run/docker.sock"
    echo "- /run/docker.sock"
    echo "- $HOME/.docker/run/docker.sock"
    exit 1
fi

echo " [OK] (Found at $DOCKER_SOCKET)"

echo -n "Checking docker-compose..."
# Check if docker-compose is installed
if ! docker compose version > /dev/null 2>&1; then
  echo " [FAIL]"
  echo "docker-compose not found. Please check your Docker installation."
  exit 1
fi
echo " [OK]"

# Try /usr/local/bin first

# Get the port that the user wants to use, or just default to 3456
port=3456  # Set default first
if [ -t 0 ]; then  # Only prompt if running in interactive terminal
    read -p "What port do you want Canine running on? (default: 3456) " port
    port=${port:-3456}
fi

echo "Building Docker images..."
echo " [OK]"

echo "Starting Canine on port $port..."

# Start docker compose in the background
docker compose build
PORT=$port DOCKER_SOCKET="$DOCKER_SOCKET" docker compose up -d

# Function to check if port is ready
wait_for_port() {
    local port=$1
    echo -n "Waiting for service to be ready..."
    while ! curl -s "http://localhost:$port" > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " [OK]"
}

# Wait for port to be ready
wait_for_port $port

echo "Opening browser to http://localhost:$port"
# Platform-independent way to open browser
if command -v xdg-open > /dev/null 2>&1; then
    xdg-open "http://localhost:$port"  # Linux
elif command -v open > /dev/null 2>&1; then
    open "http://localhost:$port"      # macOS
elif command -v start > /dev/null 2>&1; then
    start "http://localhost:$port"     # Windows
else
    echo "Please open http://localhost:$port in your browser"
fi
echo "Run 'cd $HOME/.canine/src && docker compose down' to stop Canine"
