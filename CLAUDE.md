# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Canine is a Rails-based Kubernetes deployment platform that provides an intuitive web interface for managing applications on Kubernetes clusters. The application uses Rails 7.2.2 with PostgreSQL, and GoodJob for background processing.

## Key Commands

### Development Setup & Running
```bash
# Initial setup
bin/setup

# Start development server (includes web, worker, JS, and CSS watchers)
bin/dev

# Start specific services via docker-compose
docker compose up -d
```

### Building Assets
```bash
# Build JavaScript assets
yarn build

# Build CSS (Tailwind)
yarn build:css
```

### Testing
```bash
# Run all tests (excluding system tests)
rake test

# Run all RSpec tests
rake spec

# Run specific test suites
rake spec:models
rake spec:controllers
rake spec:services
rake spec:jobs
rake spec:actions
rake spec:system

# Run a specific test file
bundle exec rspec spec/models/user_spec.rb

# Run tests with specific line number
bundle exec rspec spec/models/user_spec.rb:42
```

### Code Quality
```bash
# Ruby linting
bin/rubocop

# Auto-fix linting issues
bin/rubocop -a

# Security scanning
bin/brakeman
```

### Database
```bash
# Run migrations
rails db:migrate

# Reset test database
rails db:test:prepare

# Access Rails console
rails console
```

## Architecture Overview

### Core Components

1. **Models** (`app/models/`): Domain entities including User, Account, Project, Cluster, Service, Deployment, Build
   - Projects belong to accounts and connect to Git repositories
   - Services define deployable applications within projects
   - Deployments track individual deployment instances
   - Builds handle Docker image creation

2. **Background Jobs** (`app/jobs/`): GoodJob workers for async operations
   - `BuildJob`: Builds Docker images from source
   - `DeployJob`: Deploys applications to Kubernetes
   - `WebhookJob`: Handles Git webhooks
   - `MetricsJob`: Collects cluster metrics
   - Jobs use LightService actions for complex workflows

3. **Services** (`app/services/`): Business logic and external integrations
   - `KubernetesService`: Kubernetes API client wrapper
   - `DockerService`: Docker operations
   - `GitService`: Git repository operations
   - `HelmService`: Helm chart management

4. **Actions** (`app/actions/`): LightService-based action classes for composable workflows
   - Build workflows: clone repo, build image, push to registry
   - Deploy workflows: create K8s resources, update deployments
   - Organized by feature (builds/, deploys/, projects/)

5. **Kubernetes Integration** (`resources/k8/`): 
   - YAML templates for deployments, services, ingresses
   - Script generators for Kubernetes manifests
   - Support for multiple deployment strategies

### Frontend Architecture

- **Hotwire Stack**: Turbo + Stimulus for reactive UI without complex JavaScript
- **Tailwind CSS**: Utility-first CSS framework
- **ESBuild**: JavaScript bundling
- **Stimulus Controllers** (`app/javascript/controllers/`): Handle client-side interactions

### Authentication & Authorization

- Devise for authentication
- Pundit for authorization policies
- Account-based multi-tenancy

### External Integrations

- GitHub/GitLab webhooks for automated deployments
- Docker registry support (Docker Hub, GitHub Container Registry)
- Kubernetes cluster management via kubeconfig
- DNS providers (Cloudflare) for domain management

## Development Workflow

1. **Feature Development**: Create feature branches from `main`
2. **Testing**: Write specs for new functionality, especially for services and actions
3. **Background Jobs**: Test async operations with `perform_now` in specs
4. **Kubernetes Resources**: Update templates in `resources/k8/` for deployment changes
5. **Migrations**: Use strong migrations practices for zero-downtime deployments
6. **Linting**: Always run `rubocop -A` at the end of every development cycle

## Important Patterns

- **Service Objects**: Encapsulate complex business logic in service classes
- **LightService Actions**: Use for multi-step workflows with error handling
- **GoodJob Jobs**: All long-running operations should be async
- **Kubernetes Client**: Always use `KubernetesService` wrapper, not direct client
- **Error Handling**: Use Rails error tracking and structured logging
- **Testing**: Focus on service/action specs for business logic, request specs for APIs
