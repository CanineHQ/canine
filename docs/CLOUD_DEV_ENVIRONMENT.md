# Cloud Development Environment

The Cloud Development Environment feature allows users to spin up a live, SSH-accessible development environment alongside their running application in Kubernetes. Claude Code is pre-installed, enabling AI-assisted development with real-time code changes reflected in the running app.

## Overview

When enabled, the deployment creates a sidecar container with:
- **SSH Server**: Remote access to the development environment
- **Claude Code CLI**: AI-assisted code editing powered by Anthropic
- **Shared Codebase**: Live file sync between app and dev environment
- **Hot Reload**: Changes made via Claude Code are immediately visible in the app

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Kubernetes Pod                      │
│                                                  │
│  ┌──────────────────┐    ┌──────────────────┐  │
│  │   Main App       │    │  Dev Environment │  │
│  │   Container      │    │    Sidecar       │  │
│  │                  │    │                  │  │
│  │ - Your app       │    │ - SSH Server     │  │
│  │ - Hot reload     │    │ - Claude Code    │  │
│  │                  │    │ - Git, Vim, etc  │  │
│  └────────┬─────────┘    └────────┬─────────┘  │
│           │                       │             │
│           └───────┬───────────────┘             │
│                   │                             │
│         ┌─────────▼─────────┐                   │
│         │  Shared Volume    │                   │
│         │  (emptyDir)       │                   │
│         │  /workspace       │                   │
│         └───────────────────┘                   │
└─────────────────────────────────────────────────┘
                    │
                    │ SSH (LoadBalancer)
                    ▼
              👤 Developer
```

## Setup Guide

### 1. Configure Development Environment

Navigate to your project in Canine and create a new development environment configuration:

**Required Fields:**
- **Branch Name**: Git branch to deploy (e.g., `main`, `develop`)
- **Dockerfile Path**: Path to your dev environment Dockerfile (e.g., `./Dockerfile.dev`)
- **Application Path**: Mount path inside containers (e.g., `/app`)

**Optional Fields:**
- **Anthropic API Key**: Project-level key (falls back to account-level)
- **SSH Username**: Default is `developer`
- **SSH Password**: Auto-generated if not specified
- **SSH Port**: Default is `2222`

### 2. Create Development Dockerfile

Create a `Dockerfile.dev` (or your configured path) in your repository:

```dockerfile
FROM your-base-image:latest

# Install development tools
RUN apt-get update && apt-get install -y \
    openssh-server \
    git \
    vim \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js for Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Configure SSH
RUN mkdir /var/run/sshd
EXPOSE 2222

# Your app-specific setup
COPY . /app
WORKDIR /app

# Start your app with hot reload
CMD ["your-dev-server-command"]
```

### 3. Deploy Project

Deploy your project as usual. The build process will:
1. Build your main application image
2. Build your dev environment image (if config is enabled)
3. Deploy both images as a pod with shared volume

### 4. Connect via SSH

After deployment completes, navigate to **Project → Dev Environment** tab to view connection details:

```bash
ssh developer@your-service-dev-ssh.namespace.svc.cluster.local -p 2222
```

### 5. Use Claude Code

Once connected via SSH:

```bash
# Start Claude Code
claude-code

# Navigate to your code
cd /workspace

# Claude will help you make changes with AI assistance
```

## How It Works

### Build Process

When you deploy a project with dev environment enabled:

1. **Init Container** clones your repository into a shared volume
2. **Main Container** mounts the shared volume at your `application_path`
3. **Dev Sidecar** also mounts the shared volume, running SSH + Claude Code
4. **SSH Service** exposes the sidecar via LoadBalancer

### File Synchronization

- Code is cloned into an `emptyDir` volume at pod startup
- Both containers mount the same volume
- Changes made in the dev environment are immediately visible to the main app
- If your app has hot reload (e.g., nodemon, webpack-dev-server), changes apply instantly

### Security

- SSH passwords are auto-generated and securely stored
- Anthropic API keys are injected as environment variables
- Dev environment is isolated per-project
- Only accessible within the Kubernetes cluster or via LoadBalancer

## API Key Configuration

### Account-Level (Fallback)
Set your Anthropic API key in Account Settings. All projects without a project-level key will use this.

### Project-Level (Override)
Set a project-specific key in the dev environment configuration to override the account-level key.

**Priority**: Project-level > Account-level

## Use Cases

### 1. Live Debugging
SSH into your running production-like environment and debug issues with Claude's assistance.

### 2. Rapid Prototyping
Make changes with AI assistance and see results immediately without rebuilding.

### 3. PM Mode Agents
Autonomous AI agents can SSH in, make changes, and test them in real-time.

### 4. Pair Programming with AI
Collaborate with Claude Code to implement features while the app runs.

## Limitations

- Dev environment is ephemeral (resets on pod restart)
- Changes are not automatically committed to git
- Requires LoadBalancer support for external SSH access
- Dev image builds add time to deployment process

## Troubleshooting

### SSH Connection Refused
- Check that the deployment completed successfully
- Verify LoadBalancer has assigned an external IP
- Ensure SSH service is running: `kubectl get svc -n <namespace>`

### Claude Code Not Working
- Verify Anthropic API key is configured (project or account level)
- Check environment variable: `echo $ANTHROPIC_API_KEY`
- Ensure Claude Code is installed: `which claude-code`

### Changes Not Reflected
- Verify your app has hot reload enabled
- Check both containers mount the same volume path
- Look for file watchers in your app's dev server

### Dev Image Build Fails
- Ensure `Dockerfile.dev` exists at the configured path
- Check build logs in the Build details page
- Verify Dockerfile syntax is correct

## Advanced Configuration

### Custom SSH Port

```yaml
# In your dev environment config
ssh_port: 3000  # Use custom port instead of 2222
```

### Multiple Developers

Each project gets one dev environment. For multiple developers:
- Fork the project for separate instances, or
- Use separate branches with different dev environment configs

### Persistent Development

For persistent development environments, consider:
- Using PersistentVolumes instead of emptyDir
- Creating a separate deployment (not sidecar)
- Setting up a dedicated dev cluster

## API

### Model: `DevelopmentEnvironmentConfiguration`

```ruby
# Create
config = project.create_development_environment_configuration(
  branch_name: "main",
  dockerfile_path: "./Dockerfile.dev",
  application_path: "/app",
  anthropic_api_key: "sk-ant-...",  # Optional
  enabled: true
)

# Access
config = project.development_environment_configuration
config.effective_anthropic_api_key  # Returns project or account key
config.api_key_configured?  # Check if key is available

# Enable/Disable
config.update(enabled: false)
```

### Routes

```
GET    /projects/:slug/development_environment_configuration       # Show SSH details
GET    /projects/:slug/development_environment_configuration/new   # New form
POST   /projects/:slug/development_environment_configuration       # Create
GET    /projects/:slug/development_environment_configuration/edit  # Edit form
PATCH  /projects/:slug/development_environment_configuration       # Update
DELETE /projects/:slug/development_environment_configuration       # Delete
```

## Future Enhancements

- [ ] Web-based terminal (VS Code in browser)
- [ ] Git auto-commit on save
- [ ] Multi-user dev environments
- [ ] Dev environment snapshots
- [ ] Resource limits configuration
- [ ] Custom base images library

## Contributing

To extend or modify the dev environment feature:

1. **Model**: `app/models/development_environment_configuration.rb`
2. **Controller**: `app/controllers/projects/development_environment_configurations_controller.rb`
3. **Build Job**: `app/jobs/projects/build_job.rb` (`build_dev_environment_image`)
4. **Deployment**: `resources/k8/stateless/deployment.yaml` (sidecar section)
5. **SSH Service**: `resources/k8/stateless/dev_ssh_service.yaml`
6. **Base Image**: `docker/dev-environment/`

## Support

For issues or questions:
- Check build logs for dev image build errors
- Review deployment manifests in the Deployment details
- Inspect pod logs: `kubectl logs -n <namespace> <pod-name> -c dev-environment`
- Open an issue on GitHub

---

**Built with ❤️ for the Canine platform**
