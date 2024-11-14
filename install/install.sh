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

cd ~/.canine/src/install
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

# Try /usr/local/bin first

# Get the port that the user wants to use, or just default to 3456
port=3456  # Set default first
if [ -t 0 ]; then  # Only prompt if running in interactive terminal
    read -p "What port do you want Canine running on? (default: 3456) " port
    port=${port:-3456}
fi

echo "Building Docker images..."
echo " [OK]"

# Run docker compose with PORT environment variable
echo "Starting Canine on port $port..."
# Print working directory
PORT=$port docker-compose up
echo " [OK]"

# Open browser to http://localhost:$port
open http://localhost:$port
