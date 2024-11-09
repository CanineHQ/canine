#!/bin/bash
set -e

mkdir -p ~/.canine/src
git clone https://github.com/czhu12/canine.git ~/.canine/src

cd ~/.canine/src

# Check if /var/run/docker.sock exists
if [ ! -S /var/run/docker.sock ]; then
  echo "Docker socket not found. Please check your Docker installation."
  exit 1
fi
# Get the port that the user wants to use, or just default to 3000 if they press enter
read -p "Enter the port number to use (default: 3000):" port
if [ -z "$port" ]; then
  port=3000
fi
# Get the username that the user wants to use, or just default to none
read -p "Enter the username to use (default: none):" username
if [ -z "$username" ]; then
  username=none
fi
# Get the password that the user wants to use, or just default to none
read -p "Enter the password to use (default: none):" password
if [ -z "$password" ]; then
  password=none
fi

# Run docker compose with PORT environment variable
docker-compose up -d PORT=$port USERNAME=$username PASSWORD=$password

# Open browser to http://localhost:$port
open http://localhost:$port
