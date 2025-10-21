# Quick Start Guide

Get the demo running in 10 minutes.

## Prerequisites

Ensure you have these installed:
```bash
brew install tenv terramate terragrunt kind kubectl helm
```

Ensure Docker Desktop is running.

## One-Command Demo

```bash
# Clone and enter directory
cd opentofudemo

# Setup environment
./scripts/setup.sh

# Run full demo
./scripts/demo.sh

# When done, clean up
./scripts/cleanup.sh
```

## Manual Step-by-Step

### 1. Setup (1 minute)
```bash
./scripts/setup.sh
```

### 2. Deploy KIND Cluster (2 minutes)
```bash
cd stacks/platform/kind-cluster
terragrunt init
terragrunt apply -auto-approve
```

### 3. Deploy vclusters (3 minutes)
```bash
cd ../vcluster
terragrunt init
terragrunt apply -auto-approve
```

### 4. Deploy Team Infrastructure (4 minutes)
```bash
# Team A
cd ../../teams/team-a
terragrunt init
terragrunt apply -auto-approve

# Team B
cd ../team-b
terragrunt init
terragrunt apply -auto-approve
```

### 5. Verify (1 minute)
```bash
# Check host cluster
export KUBECONFIG="$(pwd)/../../platform/kind-cluster/kind-kubeconfig"
kubectl get nodes
kubectl get pods -A

# Check Team A
export KUBECONFIG="$(pwd)/../../platform/vcluster/vcluster-team-a.kubeconfig"
kubectl get pods -n team-a-apps

# Check Team B
export KUBECONFIG="$(pwd)/../../platform/vcluster/vcluster-team-b.kubeconfig"
kubectl get pods -n team-b-apps
```

## What's Deployed?

- **1 KIND cluster** (host Kubernetes)
- **2 vclusters** (isolated environments for team-a and team-b)
- **Team A**: nginx app + PostgreSQL database
- **Team B**: nginx app + Redis cache

## Try It Out

### Create a New Team
```bash
./scripts/create-team.sh team-c
```

### View with Terramate
```bash
# List all stacks
terramate list

# Run command across all stacks
terramate run -- pwd
```

### GitOps with Atlantis
```bash
# Start Atlantis server
atlantis server --repo-allowlist='*' --atlantis-url="http://localhost:4141"

# Open http://localhost:4141 in browser
```

## Clean Up
```bash
./scripts/cleanup.sh
```

## Next Steps

- Read [README.md](README.md) for detailed architecture
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if you hit issues
- Review [PRESENTATION.md](PRESENTATION.md) for demo talking points

## Common Commands

```bash
# View terragrunt dependency graph
cd stacks/teams/team-a
terragrunt graph-dependencies

# Plan without apply
terragrunt plan

# View outputs
terragrunt output

# Force recreate
terragrunt destroy -auto-approve
terragrunt apply -auto-approve

# Update dependencies
terragrunt init -upgrade
```

## Troubleshooting Quick Fixes

**Cluster won't start**: Increase Docker memory to 8GB

**Port conflicts**: Stop services using ports 80/443

**Permission denied**: Run `chmod +x scripts/*.sh`

**State locked**: Remove `.terraform-state/**/*.lock.info`

**Clean start**: `./scripts/cleanup.sh` then start over

For more issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

