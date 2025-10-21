# Troubleshooting Guide

Common issues and solutions for the OpenTofu Platform as a Product demo.

## Prerequisites Issues

### Docker Not Running

**Symptom**: `Cannot connect to the Docker daemon`

**Solution**:
```bash
# Start Docker Desktop
open -a Docker

# Wait for Docker to start, then verify
docker ps
```

### tenv Not Found

**Symptom**: `command not found: tenv`

**Solution**:
```bash
# Install tenv
brew install tenv

# Verify installation
tenv --version
```

### OpenTofu Version Mismatch

**Symptom**: `OpenTofu version X.Y.Z is required`

**Solution**:
```bash
# Install and use the correct version
tenv tofu install 1.8.8
tenv tofu use 1.8.8

# Verify
tofu version
```

## KIND Cluster Issues

### KIND Cluster Already Exists

**Symptom**: `cluster already exists`

**Solution**:
```bash
# Delete existing cluster
kind delete cluster --name opentofu-platform-demo

# Re-run terragrunt apply
cd stacks/platform/kind-cluster
terragrunt apply
```

### KIND Cluster Not Ready

**Symptom**: `nodes are not ready` or timeout errors

**Solution**:
```bash
# Check Docker resources - KIND needs sufficient CPU/memory
# In Docker Desktop: Settings → Resources
# Recommended: 4 CPUs, 8GB RAM

# Check cluster status
export KUBECONFIG=stacks/platform/kind-cluster/kind-kubeconfig
kubectl get nodes
kubectl get pods -A

# If stuck, delete and recreate
kind delete cluster --name opentofu-platform-demo
cd stacks/platform/kind-cluster
terragrunt destroy -auto-approve
terragrunt apply -auto-approve
```

### Port Conflicts

**Symptom**: `port is already allocated`

**Solution**:
```bash
# Find process using the port
lsof -i :80
lsof -i :443

# Kill the process or modify KIND config to use different ports
```

## vcluster Issues

### vcluster Pod Not Starting

**Symptom**: `vcluster pod is not ready`

**Solution**:
```bash
# Check vcluster pod status
export KUBECONFIG=stacks/platform/kind-cluster/kind-kubeconfig
kubectl get pods -n vcluster-team-a
kubectl describe pod -n vcluster-team-a
kubectl logs -n vcluster-team-a <pod-name>

# Common issues:
# - Insufficient resources: increase Docker limits
# - Image pull errors: check internet connection
# - Previous failed deployments: run cleanup.sh
```

### Cannot Connect to vcluster

**Symptom**: `connection refused` when using vcluster kubeconfig

**Solution**:
```bash
# Verify vcluster is running
export KUBECONFIG=stacks/platform/kind-cluster/kind-kubeconfig
kubectl get pods -n vcluster-team-a

# Regenerate kubeconfig
cd stacks/platform/vcluster
rm vcluster-team-a.kubeconfig
vcluster connect vcluster-team-a -n vcluster-team-a --update-current=false

# Or re-run terragrunt apply
terragrunt apply -auto-approve
```

### vcluster CLI Not Found

**Symptom**: `command not found: vcluster`

**Solution**:
```bash
# Download vcluster CLI (macOS)
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-darwin-amd64"
chmod +x vcluster
sudo mv vcluster /usr/local/bin/

# Verify
vcluster --version
```

## Terragrunt Issues

### Dependency Errors

**Symptom**: `dependency output not found`

**Solution**:
```bash
# Ensure dependencies are deployed first
cd stacks/platform/kind-cluster
terragrunt apply -auto-approve

cd ../vcluster
terragrunt apply -auto-approve

cd ../../teams/team-a
terragrunt apply -auto-approve
```

### State Lock Issues

**Symptom**: `state locked`

**Solution**:
```bash
# For local backend (demo), just remove lock file
rm -f .terraform-state/**/.terraform.tfstate.lock.info

# Or destroy and recreate
terragrunt destroy -auto-approve
terragrunt apply -auto-approve
```

### Terragrunt Cache Issues

**Symptom**: `cache is corrupted` or stale data

**Solution**:
```bash
# Clear terragrunt cache
find stacks -type d -name ".terragrunt-cache" -exec rm -rf {} +

# Re-initialize
cd stacks/platform/kind-cluster
terragrunt init -upgrade
```

## Kubernetes Provider Issues

### Provider Authentication Errors

**Symptom**: `unable to authenticate`

**Solution**:
```bash
# Ensure kubeconfig path is correct
# Check terragrunt.hcl dependency outputs

# Verify kubeconfig file exists
ls -l stacks/platform/kind-cluster/kind-kubeconfig
ls -l stacks/platform/vcluster/vcluster-*.kubeconfig

# Test connection manually
export KUBECONFIG=stacks/platform/kind-cluster/kind-kubeconfig
kubectl cluster-info
```

### Resources Already Exist

**Symptom**: `resource already exists`

**Solution**:
```bash
# Import existing resource
cd stacks/teams/team-a
terragrunt import kubernetes_namespace.app team-a-apps

# Or delete and recreate
kubectl delete namespace team-a-apps
terragrunt apply -auto-approve
```

## Helm Issues

### Helm Repository Errors

**Symptom**: `repository not found`

**Solution**:
```bash
# Add repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add loft https://charts.loft.sh
helm repo update

# Verify
helm repo list
```

### Helm Release Failed

**Symptom**: `helm release failed`

**Solution**:
```bash
# Check release status
export KUBECONFIG=stacks/platform/vcluster/vcluster-team-a.kubeconfig
helm list -A

# Get release details
helm status <release-name> -n <namespace>

# Uninstall and let terragrunt recreate
helm uninstall <release-name> -n <namespace>
cd stacks/teams/team-a
terragrunt apply -auto-approve
```

## Atlantis Issues

### Atlantis Not Starting

**Symptom**: Atlantis server won't start

**Solution**:
```bash
# Check if port 4141 is in use
lsof -i :4141

# Start with debug logging
atlantis server \
  --repo-allowlist='*' \
  --atlantis-url="http://localhost:4141" \
  --log-level=debug
```

### Atlantis Cannot Find Terragrunt

**Symptom**: `terragrunt: command not found` in Atlantis logs

**Solution**:
```bash
# Ensure terragrunt is in PATH
which terragrunt

# Add to PATH if needed
export PATH="$PATH:/usr/local/bin"

# Or specify full path in atlantis.yaml
```

## Performance Issues

### Slow Deployments

**Solution**:
- Increase Docker Desktop resources (CPU/Memory)
- Use faster storage (SSD)
- Disable unnecessary services
- Use local registry for images

### Out of Memory

**Symptom**: Pods being evicted or OOMKilled

**Solution**:
```bash
# Increase Docker memory limit
# Docker Desktop → Settings → Resources → Memory

# Reduce resource requests in Terraform configs
# Edit main.tf files to lower memory/CPU requests
```

## Clean Start

If all else fails, clean slate:

```bash
# Run cleanup
./scripts/cleanup.sh

# Verify everything is gone
kind get clusters
docker ps

# Delete Docker volumes (if needed)
docker volume prune

# Start fresh
./scripts/setup.sh
./scripts/demo.sh
```

## Getting Help

If you encounter issues not listed here:

1. Check logs:
   ```bash
   kubectl logs -n <namespace> <pod-name>
   kubectl describe pod -n <namespace> <pod-name>
   ```

2. Verify resources:
   ```bash
   kubectl get events --sort-by='.lastTimestamp'
   kubectl top nodes
   kubectl top pods -A
   ```

3. Enable debug logging:
   ```bash
   export TF_LOG=DEBUG
   export TG_LOG=debug
   ```

4. Check GitHub issues:
   - [KIND Issues](https://github.com/kubernetes-sigs/kind/issues)
   - [vcluster Issues](https://github.com/loft-sh/vcluster/issues)
   - [Terragrunt Issues](https://github.com/gruntwork-io/terragrunt/issues)
   - [OpenTofu Issues](https://github.com/opentofu/opentofu/issues)

