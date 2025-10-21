# Architecture Documentation

## Overview

This demo implements a three-layer "Platform as a Product" architecture where teams can self-service infrastructure requests through a GitOps workflow.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                          Developer Workflow                                  │
│                                                                              │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐       │
│  │ Request  │─────▶│ Create   │─────▶│ Atlantis │─────▶│ Approve  │       │
│  │ Infra    │      │ PR       │      │ Plan     │      │ & Apply  │       │
│  └──────────┘      └──────────┘      └──────────┘      └──────────┘       │
│                                                                              │
└────────────────────────────────────┬─────────────────────────────────────────┘
                                     │
                                     │ GitOps Workflow
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                      Infrastructure Layers                                   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                       │  │
│  │  Layer 1: Host Kubernetes Cluster (KIND)                            │  │
│  │                                                                       │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                     │  │
│  │  │  Node 1    │  │  Node 2    │  │  Node 3    │                     │  │
│  │  │ (Control)  │  │ (Worker)   │  │ (Worker)   │                     │  │
│  │  └────────────┘  └────────────┘  └────────────┘                     │  │
│  │                                                                       │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │                                                                 │ │  │
│  │  │  Layer 2: Virtual Clusters (vcluster)                         │ │  │
│  │  │                                                                 │ │  │
│  │  │  ┌─────────────────────┐  ┌─────────────────────┐            │ │  │
│  │  │  │  vcluster-team-a    │  │  vcluster-team-b    │            │ │  │
│  │  │  │  ┌──────────────┐   │  │  ┌──────────────┐   │            │ │  │
│  │  │  │  │ Virtual API  │   │  │  │ Virtual API  │   │            │ │  │
│  │  │  │  │ Server       │   │  │  │ Server       │   │            │ │  │
│  │  │  │  └──────────────┘   │  │  └──────────────┘   │            │ │  │
│  │  │  │                     │  │                     │            │ │  │
│  │  │  │  Layer 3: Apps      │  │  Layer 3: Apps      │            │ │  │
│  │  │  │  ┌──────────────┐   │  │  ┌──────────────┐   │            │ │  │
│  │  │  │  │ Namespace    │   │  │  │ Namespace    │   │            │ │  │
│  │  │  │  │ - nginx app  │   │  │  │ - nginx app  │   │            │ │  │
│  │  │  │  │ - PostgreSQL │   │  │  │ - Redis      │   │            │ │  │
│  │  │  │  │ - Secrets    │   │  │  │ - Secrets    │   │            │ │  │
│  │  │  │  │ - ConfigMaps │   │  │  │ - ConfigMaps │   │            │ │  │
│  │  │  │  └──────────────┘   │  │  └──────────────┘   │            │ │  │
│  │  │  └─────────────────────┘  └─────────────────────┘            │ │  │
│  │  │                                                                 │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Layer Details

### Layer 1: Host Cluster (KIND)

**Purpose**: Foundation cluster that hosts all virtual clusters

**Technology**: 
- KIND (Kubernetes in Docker)
- In production: EKS, GKE, AKS, or on-premise Kubernetes

**Components**:
- Control plane node
- Worker nodes (2 in demo)
- Core Kubernetes services (kube-system namespace)

**Management**:
- OpenTofu stack: `stacks/platform/kind-cluster/`
- Terragrunt for configuration
- tenv for version control

**Key Files**:
```
stacks/platform/kind-cluster/
├── main.tf           # KIND cluster definition
├── outputs.tf        # Exports kubeconfig path, cluster info
├── terragrunt.hcl    # Terragrunt config
└── stack.tm.hcl      # Terramate metadata
```

### Layer 2: Virtual Clusters (vcluster)

**Purpose**: Provide isolated Kubernetes environments per team

**Technology**:
- vcluster (Loft)
- Deployed via Helm charts
- Each vcluster runs as a StatefulSet in the host cluster

**Features**:
- Full Kubernetes API compatibility
- Isolated control plane per team
- Resource syncing to host cluster
- Separate kubeconfig per team

**Components per vcluster**:
- Virtual API server
- Virtual controller manager
- Virtual etcd (or SQLite)
- Syncer component

**Management**:
- OpenTofu stack: `stacks/platform/vcluster/`
- Dependencies: KIND cluster must exist
- Generates kubeconfig for each team

**Key Files**:
```
stacks/platform/vcluster/
├── main.tf           # vcluster Helm releases
├── outputs.tf        # Exports kubeconfig paths per team
├── terragrunt.hcl    # Depends on KIND cluster
└── stack.tm.hcl      # Terramate metadata
```

### Layer 3: Team Infrastructure

**Purpose**: Team-specific resources (applications, databases, etc.)

**Technology**:
- Deployed via OpenTofu into team's vcluster
- Uses Kubernetes provider
- Helm for complex applications

**Resources per team**:
- Namespaces
- Deployments (apps)
- Services
- ConfigMaps & Secrets
- Databases (via Helm)
- Caches (via Helm)

**Team A Example**:
```
team-a-apps namespace:
├── nginx deployment (2 replicas)
├── nginx service
├── PostgreSQL database (Helm)
├── Database credentials (Secret)
└── Team info (ConfigMap)
```

**Team B Example**:
```
team-b-apps namespace:
├── nginx deployment (2 replicas)
├── nginx service
├── Redis cache (Helm)
├── Redis credentials (Secret)
└── Team info (ConfigMap)
```

**Management**:
- OpenTofu stacks: `stacks/teams/*/`
- Dependencies: Respective vcluster must exist
- Uses team-specific kubeconfig

**Key Files per Team**:
```
stacks/teams/team-a/
├── main.tf           # Team infrastructure
├── outputs.tf        # Exports service endpoints
├── terragrunt.hcl    # Depends on vcluster
└── stack.tm.hcl      # Terramate metadata
```

## Tool Integration

### tenv (Version Management)

**Role**: Ensures consistent OpenTofu version across all stacks

**Configuration**: `.tenv.tofu.version`
```
1.8.8
```

**Benefits**:
- No version conflicts
- Automatic installation
- Works in CI/CD
- Multiple version support

### terramate (Stack Generation)

**Role**: Generate new stacks from templates

**Configuration**: `terramate.tm.hcl`
```hcl
terramate {
  config {
    disable_telemetry = true
  }
}

globals {
  project = "opentofu-platform-demo"
  managed_by = "terramate"
}
```

**Stack Metadata**: Each stack has `stack.tm.hcl`
```hcl
stack {
  name        = "Team A Stack"
  description = "Infrastructure stack for Team A"
  tags        = ["team", "application", "layer-3"]
  id          = "teams/team-a"
  after       = ["platform/vcluster"]
}
```

**Benefits**:
- Consistent stack structure
- Dependency tracking
- Bulk operations
- Template-based generation

### terragrunt (Dependency Management)

**Role**: Manage dependencies and shared configuration

**Root Configuration**: `terragrunt.hcl`
```hcl
# Shared backend configuration
remote_state {
  backend = "local"
  config = {
    path = "${local.state_file_path}"
  }
}

# Common inputs
inputs = {
  project_name = "opentofu-platform-demo"
  environment  = "demo"
  managed_by   = "terragrunt"
}
```

**Dependency Example**: Team A depends on vcluster
```hcl
dependency "vcluster" {
  config_path = "../../platform/vcluster"
}

inputs = {
  vcluster_kubeconfig_path = dependency.vcluster.outputs.team_kubeconfig_paths["team-a"]
}
```

**Dependency Graph**:
```
kind-cluster (no dependencies)
    ↓
vcluster (depends on kind-cluster)
    ↓
team-a, team-b (depend on vcluster)
```

**Benefits**:
- Automatic dependency resolution
- DRY configuration
- State management
- Multi-stack orchestration

### atlantis (GitOps Workflow)

**Role**: Automated infrastructure changes via pull requests

**Configuration**: `atlantis.yaml`
```yaml
version: 3
projects:
  - name: platform-kind-cluster
    dir: stacks/platform/kind-cluster
    workflow: terragrunt
    apply_requirements:
      - approved
      - mergeable
```

**Workflow**:
1. Developer creates PR with infrastructure changes
2. Atlantis detects changes, runs `terragrunt plan`
3. Plan posted as PR comment
4. Team reviews plan
5. PR approved
6. Developer comments `atlantis apply`
7. Atlantis runs `terragrunt apply`
8. Results posted to PR
9. Infrastructure deployed

**Benefits**:
- Code review for infrastructure
- Plan before apply
- Complete audit trail
- Team collaboration
- No direct production access needed

## Data Flow

### Deployment Flow

```
┌─────────────┐
│   tenv      │──▶ Installs OpenTofu 1.8.8
└─────────────┘
      │
      ▼
┌─────────────┐
│ terragrunt  │──▶ Reads root config
└─────────────┘
      │
      ▼
┌─────────────┐
│ Layer 1:    │──▶ Deploys KIND cluster
│ KIND        │    Exports kubeconfig
└─────────────┘
      │
      ▼
┌─────────────┐
│ Layer 2:    │──▶ Uses KIND kubeconfig
│ vcluster    │    Deploys vclusters
│             │    Exports team kubeconfigs
└─────────────┘
      │
      ▼
┌─────────────┐
│ Layer 3:    │──▶ Uses team kubeconfig
│ Team Stacks │    Deploys apps/databases
└─────────────┘
```

### State Management

```
.terraform-state/
├── platform/
│   ├── kind-cluster/
│   │   └── terraform.tfstate
│   └── vcluster/
│       └── terraform.tfstate
└── teams/
    ├── team-a/
    │   └── terraform.tfstate
    └── team-b/
        └── terraform.tfstate
```

Each stack maintains independent state with explicit dependencies via terragrunt.

## Security Model

### Isolation Layers

1. **Network Isolation**: vcluster provides network boundaries
2. **Resource Isolation**: Separate namespaces and quotas
3. **API Isolation**: Each team has their own API server
4. **Credential Isolation**: Separate kubeconfigs per team

### Access Control

```
Platform Team:
├── Access to host cluster (KIND)
├── Manage vclusters
└── Global policies

Team A:
├── Access to vcluster-team-a only
├── Cluster-admin within their vcluster
└── Cannot see other teams

Team B:
├── Access to vcluster-team-b only
├── Cluster-admin within their vcluster
└── Cannot see other teams
```

### In Production

- RBAC with fine-grained permissions
- OIDC/SSO integration
- Network policies
- Pod Security Standards
- Secret encryption at rest
- Audit logging

## Scalability

### Current Demo

- 1 host cluster
- 2 vclusters
- 2 team stacks
- ~10-20 pods total

### Production Scale

**Single host cluster can support**:
- 30+ vclusters comfortably
- 100+ vclusters tested
- Depends on:
  - Host cluster resources
  - Team workload sizes
  - Resource limits

**Scaling strategies**:
1. **Vertical**: Increase host cluster resources
2. **Horizontal**: Multiple host clusters, federated
3. **Hybrid**: Mix of dedicated and vcluster teams

## Cost Model

### Resource Efficiency

**Without vcluster** (dedicated clusters):
```
10 teams × 1 cluster each = 10 clusters
Control plane overhead per cluster: ~$50-150/month
Total: $500-1500/month just for control planes
Plus: Worker nodes per cluster
```

**With vcluster**:
```
1 host cluster + 10 vclusters
Control plane: $50-150/month (shared)
vclusters: ~$5-10/month each (lightweight)
Total: ~$150-250/month
Savings: 70-85%
```

### Cost Tracking

Tag resources per team:
```hcl
labels = {
  team       = "team-a"
  project    = "opentofu-platform-demo"
  managed-by = "terragrunt"
  cost-center = "engineering"
}
```

Use cloud provider cost allocation tools to track per-team spending.

## Disaster Recovery

### Backup Strategy

1. **State Files**: 
   - Production: Store in S3/GCS with versioning
   - Backup regularly
   
2. **Configurations**:
   - Git as source of truth
   - All changes in version control

3. **Data**:
   - Database backups (per-team strategy)
   - PV snapshots for stateful workloads

### Recovery Procedure

```bash
# 1. Restore host cluster
cd stacks/platform/kind-cluster
terragrunt apply

# 2. Restore vclusters
cd ../vcluster
terragrunt apply

# 3. Restore team stacks
cd ../../teams/team-a
terragrunt apply
```

All state is reproducible from Git + state files.

## Monitoring & Observability

### Metrics to Track

**Platform Level**:
- Host cluster resource utilization
- vcluster health and resource usage
- Deployment success rates
- Time to provision new teams

**Team Level**:
- Application metrics
- Database performance
- Resource quotas vs. usage
- Cost per team

### Recommended Tools

- **Prometheus**: Metrics collection
- **Grafana**: Dashboards
- **Loki**: Log aggregation
- **Jaeger**: Distributed tracing
- **Cost tools**: Kubecost, OpenCost

## Production Considerations

### Differences from Demo

| Component | Demo | Production |
|-----------|------|------------|
| Host Cluster | KIND | EKS/GKE/AKS |
| State Backend | Local | S3/GCS |
| State Locking | None | DynamoDB/GCS |
| Secrets | Plain text | Vault/SOPS |
| Monitoring | None | Prometheus/Grafana |
| Backups | None | Automated |
| HA | Single node | Multi-AZ |
| Networking | Default | Custom VPC/Network Policies |
| DNS | CoreDNS | ExternalDNS |
| Certs | Self-signed | Cert-manager + Let's Encrypt |

### Migration Path

1. Replace KIND with cloud Kubernetes
2. Configure remote state (S3/GCS)
3. Add secret management (Vault/SOPS)
4. Implement monitoring
5. Configure backups
6. Add network policies
7. Implement RBAC with SSO
8. Add cost tracking
9. Integrate with CI/CD
10. Train teams

## Further Reading

- [vcluster Documentation](https://www.vcluster.com/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [Terramate Documentation](https://terramate.io/docs)
- [Atlantis Documentation](https://www.runatlantis.io/docs/)
- [OpenTofu Documentation](https://opentofu.org/docs/)

