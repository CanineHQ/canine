# Development Environment Sidecar

This Docker image provides an SSH-accessible development environment with Claude Code CLI pre-installed.

## Features

- SSH server for remote access
- Claude Code CLI for AI-assisted development
- Git, Vim, Nano pre-installed
- Configurable user credentials
- Shared volume support for live code editing

## Building

```bash
docker build -t ghcr.io/caninehq/dev-environment:latest .
```

## Pushing to GitHub Container Registry

```bash
docker push ghcr.io/caninehq/dev-environment:latest
```

## Environment Variables

- `SSH_USERNAME`: SSH username (default: developer)
- `SSH_PASSWORD`: SSH password (generated automatically in deployment)
- `ANTHROPIC_API_KEY`: API key for Claude Code (required)
- `WORKSPACE_PATH`: Path to the shared codebase (default: /workspace)
- `SSH_PORT`: SSH port (default: 2222)

## Usage

The container is automatically deployed as a sidecar when a Development Environment Configuration is enabled for a project.
