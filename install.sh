#!/bin/bash
set -e

echo -n "Cloning Canine..."
mkdir -p ~/.canine
# Remove existing src directory if it exists
#rm -rf ~/.canine/src
# Only clone if the directory is empty
if [ -z "$(ls -A ~/.canine/src)" ]; then
  # Shallow clone the repo
  git clone --depth 1 https://github.com/czhu12/canine.git ~/.canine/src
fi

cd ~/.canine/src
echo " [OK]"

echo -n "Checking Docker..."
# Check if /var/run/docker.sock exists
if [ ! -S "/var/run/docker.sock" ]; then
  echo " [FAIL]"
  echo "Docker socket not found at /var/run/docker.sock. Please check your Docker installation and ensure docker is running."
  exit 1
fi
echo " [OK]"

echo -n "Checking docker-compose..."
# Check if docker-compose is installed
if ! docker compose version > /dev/null 2>&1; then
  echo " [FAIL]"
  echo "docker-compose not found. Please check your Docker installation."
  exit 1
fi
echo " [OK]"

# Get the port that the user wants to use, or just default to 3456 if they press enter
read -p "What port do you want Canine running on? (default: 3456) " port
if [ -z "$port" ]; then
  port=3456
fi

# Run docker compose with PORT environment variable
echo "Starting Canine on port $port..."
# Print working directory
echo "Current directory: $(pwd)"
PORT=$port docker-compose up -d
echo " [OK]"

# Open browser to http://localhost:$port
open http://localhost:$port
