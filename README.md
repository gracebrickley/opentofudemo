# OpenTofu Platform as a Product Demo

This demo showcases how modern IaC tools work together to build a self-service infrastructure platform.

## Overview

This demo illustrates a "Platform as a Product" model where:
- **App teams** request infrastructure (databases, clusters, etc.) via self-service
- **Platform team** provisions it automatically through the OpenTofu stack
- **GitOps workflow** ensures consistent, auditable deployments

## Tools in This Demo

### 1. **tenv** - Version Management
Ensures all teams use standardized versions of OpenTofu across all service templates.

### 2. **terramate** - Stack Generation
Automatically generates new stack templates when a team requests a service.

### 3. **terragrunt** - Dependency Management
Manages dependencies and shared state between team services, ensuring proper order of operations.

### 4. **atlantis** - GitOps Workflow
Runs automated plans and applies per service repository through pull requests.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   KIND Host Cluster                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  vcluster-1  │  │  vcluster-2  │  │  vcluster-3  │  │
│  │   (Team A)   │  │   (Team B)   │  │   (Team C)   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Layer 1: Host Cluster (KIND)
- Local Kubernetes cluster using KIND (Kubernetes in Docker)
- Managed by OpenTofu stack in `stacks/platform/kind-cluster/`

### Layer 2: Virtual Clusters (vcluster)
- One virtual cluster per team/user for isolation
- Managed by OpenTofu stack in `stacks/platform/vcluster/`
- **Dependency**: Requires KIND cluster to exist first

### Layer 3: Application Infrastructure
- Team-specific resources (databases, services, etc.)
- Deployed into virtual clusters using team-specific kubeconfig
- Managed by OpenTofu stacks in `stacks/teams/*/`
- **Dependency**: Requires vcluster to be provisioned first

## Project Structure

```
.
├── README.md
├── .tenv.tofu.version          # tenv version pinning
├── terramate.tm.hcl            # terramate root configuration
├── atlantis.yaml               # atlantis configuration
├── stacks/
│   ├── platform/
│   │   ├── kind-cluster/       # Layer 1: Host cluster
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── terragrunt.hcl
│   │   └── vcluster/           # Layer 2: Virtual clusters
│   │       ├── main.tf
│   │       ├── outputs.tf
│   │       └── terragrunt.hcl
│   └── teams/
│       ├── team-a/             # Layer 3: Team A resources
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   └── terragrunt.hcl
│       └── team-b/             # Layer 3: Team B resources
│           ├── main.tf
│           ├── outputs.tf
│           └── terragrunt.hcl
├── templates/
│   └── team-stack/             # terramate template for new teams
└── scripts/
    ├── setup.sh                # Initial setup script
    ├── create-team.sh          # Create new team stack
    └── demo.sh                 # Run the full demo
```

## Documentation

- **[Project Summary](SUMMARY.md)** - High-level overview of what was built
- **[Quick Start Guide](QUICKSTART.md)** - Get running in 10 minutes
- **[Architecture Documentation](ARCHITECTURE.md)** - Deep dive into the system design
- **[Presentation Notes](PRESENTATION.md)** - Talking points for demos
- **[Demo Script](DEMO_SCRIPT.md)** - Live demo cheat sheet
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions

## Prerequisites

Install the required tools:

```bash
# tenv (manages OpenTofu/Terraform versions)
brew install tenv

# terramate (stack generation)
brew install terramate

# terragrunt (dependency management)
brew install terragrunt

# atlantis (GitOps workflow)
brew install atlantis

# KIND (Kubernetes in Docker)
brew install kind

# kubectl
brew install kubectl

# helm (for vcluster)
brew install helm
```

## Quick Start

### Option 1: Automated Demo (Recommended)

```bash
# Setup and verify prerequisites
./scripts/setup.sh

# Run full demo
./scripts/demo.sh

# Clean up when done
./scripts/cleanup.sh
```

### Option 2: Using Makefile

```bash
# Check prerequisites
make check-tools

# Deploy everything
make all

# Or deploy step by step
make kind      # Layer 1
make vcluster  # Layer 2
make teams     # Layer 3

# Check status
make verify

# Clean up
make clean
```

### Option 3: Manual Step-by-Step

See [QUICKSTART.md](QUICKSTART.md) for detailed manual instructions.

## Demo Workflow

### Scenario: Team C Requests a New Database

1. **Team requests infrastructure** via PR:
   ```bash
   git checkout -b feature/team-c-database
   ./scripts/create-team.sh team-c
   cd stacks/teams/team-c
   # Edit main.tf to add database configuration
   git commit -am "Add Team C database stack"
   git push
   ```

2. **Atlantis automatically runs** `plan`:
   - Detects changes in the PR
   - Runs terragrunt plan with proper dependencies
   - Posts plan output as PR comment

3. **Team reviews and approves**:
   - Reviews the plan in the PR
   - Comments `atlantis apply` to provision

4. **Atlantis applies changes**:
   - Runs terragrunt apply
   - vcluster is provisioned via terragrunt dependency
   - Database is deployed into the vcluster
   - Posts results as PR comment

5. **Infrastructure is ready**:
   - Team C receives kubeconfig
   - Database credentials are stored in secrets
   - Team can start using their infrastructure

## Key Concepts Demonstrated

### 1. Version Consistency (tenv)
- `.tenv.tofu.version` ensures all teams use the same OpenTofu version
- Prevents "works on my machine" issues

### 2. Stack Generation (terramate)
- `terramate create` generates new team stacks from templates
- Consistent structure across all teams
- Reduces manual configuration errors

### 3. Dependency Management (terragrunt)
- `terragrunt.hcl` defines dependencies between stacks
- Ensures KIND cluster exists before vcluster deployment
- Ensures vcluster exists before team resources
- Shared remote state configuration

### 4. GitOps Workflow (atlantis)
- All infrastructure changes go through pull requests
- Automatic plan/apply workflow
- Audit trail of all changes
- Team collaboration on infrastructure

## Cleaning Up

```bash
# Destroy team resources
cd stacks/teams/team-a && terragrunt destroy
cd ../team-b && terragrunt destroy

# Destroy platform
cd ../../platform/vcluster && terragrunt destroy
cd ../kind-cluster && terragrunt destroy
```

## Next Steps

- Add more service types (RDS, Redis, S3, etc.)
- Integrate with a real self-service portal
- Add policy enforcement (OPA, Sentinel)
- Add cost tracking and quotas
- Implement approval workflows

## Additional Operations

### Create a New Team

```bash
# Using script
./scripts/create-team.sh team-c

# Or using Makefile
make create-team TEAM=team-c
```

### View Logs

```bash
# KIND cluster logs
make logs-kind

# Team A logs
make logs-team-a

# Team B logs
make logs-team-b
```

### Interactive Shells

```bash
# Shell with KIND cluster access
make shell-kind

# Shell with Team A vcluster access
make shell-team-a

# Shell with Team B vcluster access
make shell-team-b
```

### Terramate Operations

```bash
# List all stacks
terramate list

# Show stack details
terramate list --why

# Run command across all stacks
terramate run -- pwd
```

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

### Quick Fixes

- **Cluster won't start**: Increase Docker memory to 8GB in Docker Desktop settings
- **Port conflicts**: Stop services using ports 80/443
- **Permission denied**: Run `chmod +x scripts/*.sh`
- **State locked**: Run `make clean-cache`
- **Clean start**: Run `./scripts/cleanup.sh` and start over

## Project Structure

```
opentofudemo/
├── README.md                   # This file
├── QUICKSTART.md              # Quick start guide
├── ARCHITECTURE.md            # Architecture deep dive
├── PRESENTATION.md            # Presentation notes
├── TROUBLESHOOTING.md         # Troubleshooting guide
├── Makefile                   # Convenient make targets
├── .tenv.tofu.version         # OpenTofu version (1.8.8)
├── terramate.tm.hcl           # Terramate root config
├── terragrunt.hcl             # Terragrunt root config
├── atlantis.yaml              # Atlantis configuration
├── atlantis-repos.yaml        # Atlantis repo settings
├── scripts/
│   ├── setup.sh              # Initial setup
│   ├── demo.sh               # Full demo
│   ├── create-team.sh        # Create new team
│   └── cleanup.sh            # Clean up
├── stacks/
│   ├── platform/
│   │   ├── kind-cluster/     # Layer 1: Host cluster
│   │   └── vcluster/         # Layer 2: Virtual clusters
│   └── teams/
│       ├── team-a/           # Layer 3: Team A resources
│       └── team-b/           # Layer 3: Team B resources
└── templates/
    └── team-stack/           # Template for new teams
```

## Contributing

Contributions are welcome! This demo is designed to be a starting point for your own Platform as a Product implementation.

### Areas for Contribution

- Additional service types (RDS, S3, message queues, etc.)
- Production-grade security configurations
- Cost tracking and quota management
- Policy enforcement examples (OPA, Kyverno)
- Multi-cloud support
- Enhanced monitoring and observability
- Improved team onboarding workflows

## Acknowledgments

This demo showcases the power of open-source IaC tools:

- **[OpenTofu](https://opentofu.org)** - Open-source Terraform alternative
- **[tenv](https://github.com/tofuutils/tenv)** - Version manager
- **[terramate](https://terramate.io)** - Stack management
- **[terragrunt](https://terragrunt.gruntwork.io)** - Terraform/OpenTofu wrapper
- **[atlantis](https://www.runatlantis.io)** - GitOps for Terraform/OpenTofu
- **[vcluster](https://www.vcluster.com)** - Virtual Kubernetes clusters
- **[KIND](https://kind.sigs.k8s.io)** - Kubernetes in Docker

## License

MIT - See [LICENSE](LICENSE) file for details.

