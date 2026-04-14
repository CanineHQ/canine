#!/bin/bash
set -e

# Create user with provided credentials
SSH_USERNAME=${SSH_USERNAME:-developer}
SSH_PASSWORD=${SSH_PASSWORD:-changeme}
WORKSPACE_PATH=${WORKSPACE_PATH:-/workspace}

# Create user if it doesn't exist
if ! id "$SSH_USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash "$SSH_USERNAME"
    echo "$SSH_USERNAME:$SSH_PASSWORD" | chpasswd

    # Add user to sudoers
    echo "$SSH_USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

# Set up Claude Code configuration
mkdir -p /home/$SSH_USERNAME/.config/claude
cat > /home/$SSH_USERNAME/.config/claude/config.json <<EOF
{
  "apiKey": "${ANTHROPIC_API_KEY}"
}
EOF

# Create workspace directory
mkdir -p "$WORKSPACE_PATH"
chown -R $SSH_USERNAME:$SSH_USERNAME "$WORKSPACE_PATH"
chown -R $SSH_USERNAME:$SSH_USERNAME /home/$SSH_USERNAME

# Configure SSH to listen on custom port
SSH_PORT=${SSH_PORT:-2222}
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config

# Start SSH daemon
/usr/sbin/sshd -D
