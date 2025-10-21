# Presentation Notes: Platform as a Product with OpenTofu

## Introduction (2 minutes)

### The Problem
- Teams need infrastructure (databases, clusters, queues, etc.)
- Traditional approach: Manual provisioning, tickets, waiting
- Result: Slow time-to-market, inconsistent configurations, security risks

### The Solution: Platform as a Product
- Self-service infrastructure provisioning
- Standardized, secure, pre-approved configurations
- GitOps workflow for auditability
- Multi-tenancy with strong isolation

## Architecture Overview (3 minutes)

### Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 Layer 1: Host Cluster                    │
│                      (KIND)                              │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │          Layer 2: Virtual Clusters               │  │
│  │              (vcluster)                          │  │
│  │                                                  │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐        │  │
│  │  │ Team A  │  │ Team B  │  │ Team C  │        │  │
│  │  └─────────┘  └─────────┘  └─────────┘        │  │
│  │                                                  │  │
│  │  Layer 3: Application Infrastructure            │  │
│  │  (Databases, Apps, Services)                    │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Why This Architecture?
- **Isolation**: Each team gets their own virtual cluster
- **Cost-Effective**: Share one host cluster, multiply with vclusters
- **Flexibility**: Teams can have cluster-admin in their vcluster
- **Security**: Strong boundaries between teams

## The Tools (5 minutes)

### 1. tenv - Version Management
**Purpose**: Ensure everyone uses the same OpenTofu version

```bash
# .tenv.tofu.version
1.8.8
```

**Demo Points**:
- Single source of truth for versions
- No more "works on my machine"
- Automatic installation and switching
- Works with CI/CD pipelines

### 2. terramate - Stack Generation
**Purpose**: Automatically generate infrastructure stacks from templates

**Demo Points**:
- Templates in `templates/team-stack/`
- Generate new team with one command
- Consistent structure across teams
- Reduces human error

**Show**:
```bash
./scripts/create-team.sh team-c
```

### 3. terragrunt - Dependency Management
**Purpose**: Manage dependencies and shared configuration

**Key Features**:
- Dependency resolution (KIND → vcluster → team resources)
- DRY configuration (Don't Repeat Yourself)
- Remote state management
- Multi-stack orchestration

**Show**: `stacks/teams/team-a/terragrunt.hcl`
```hcl
dependency "vcluster" {
  config_path = "../../platform/vcluster"
}

inputs = {
  vcluster_kubeconfig_path = dependency.vcluster.outputs.team_kubeconfig_paths["team-a"]
}
```

### 4. atlantis - GitOps Workflow
**Purpose**: Automated, PR-based infrastructure changes

**Workflow**:
1. Developer creates PR with infrastructure change
2. Atlantis automatically runs `plan`
3. Team reviews plan in PR comments
4. Approval required before apply
5. Comment `atlantis apply` to provision
6. Complete audit trail in Git history

**Demo Points**:
- All changes go through code review
- Plan before apply (no surprises)
- Audit trail for compliance
- Team collaboration on infrastructure

## Live Demo (10 minutes)

### Setup (Show, don't run)
```bash
./scripts/setup.sh
```
- Checks prerequisites
- Installs OpenTofu via tenv
- Configures environment

### Part 1: Deploy Platform (3 minutes)

**Layer 1: KIND Cluster**
```bash
cd stacks/platform/kind-cluster
terragrunt apply
```

**Talking Points**:
- Creates local Kubernetes cluster
- Production would be EKS, GKE, AKS
- Takes 1-2 minutes

**Show**:
```bash
export KUBECONFIG=kind-kubeconfig
kubectl get nodes
```

**Layer 2: vclusters**
```bash
cd ../vcluster
terragrunt apply
```

**Talking Points**:
- Notice terragrunt automatically resolves KIND dependency
- Deploys two vclusters (team-a, team-b)
- Takes 2-3 minutes
- Each team gets isolated Kubernetes cluster

**Show**:
```bash
kubectl get pods -A | grep vcluster
```

### Part 2: Deploy Team Infrastructure (3 minutes)

**Team A: PostgreSQL Database**
```bash
cd ../../teams/team-a
terragrunt apply
```

**Talking Points**:
- Deploys into team-a's virtual cluster
- Includes: namespace, app, database
- Team-specific kubeconfig from vcluster dependency
- Takes 2-3 minutes

**Show**:
```bash
export KUBECONFIG=../../platform/vcluster/vcluster-team-a.kubeconfig
kubectl get all -n team-a-apps
```

**Team B: Redis Cache**
```bash
cd ../team-b
terragrunt apply
```

**Talking Points**:
- Different resources for different teams
- Same process, different outcomes
- Complete isolation from team-a

### Part 3: GitOps with Atlantis (2 minutes)

**Show Configuration**: `atlantis.yaml`
- Projects defined per stack
- Automatic planning on PR
- Approval requirements
- Custom workflows

**Explain Workflow**:
1. Developer: `git checkout -b add-team-c-database`
2. Developer: `./scripts/create-team.sh team-c`
3. Developer: Edit `stacks/teams/team-c/main.tf`
4. Developer: `git commit && git push`
5. Atlantis: Auto-runs `plan`, posts to PR
6. Team: Reviews plan, approves PR
7. Developer: Comments `atlantis apply`
8. Atlantis: Runs `apply`, team-c gets infrastructure
9. Team: Receives kubeconfig, starts using resources

**Demo** (if time):
```bash
atlantis server --repo-allowlist='*' --atlantis-url="http://localhost:4141"
```

### Part 4: Create New Team (2 minutes)

**Show Terramate in Action**:
```bash
./scripts/create-team.sh team-c
```

**Talking Points**:
- Generates complete stack from template
- Consistent structure
- Ready to customize
- Can be committed and deployed via Atlantis

**Show Generated Files**:
```bash
ls -la stacks/teams/team-c/
cat stacks/teams/team-c/stack.tm.hcl
```

## Key Benefits (3 minutes)

### For Development Teams
- ✅ Self-service infrastructure
- ✅ Fast provisioning (minutes, not days)
- ✅ Safe experimentation in virtual clusters
- ✅ Standard, pre-approved configurations
- ✅ No waiting for platform team

### For Platform Teams
- ✅ Reduced manual work
- ✅ Consistent configurations
- ✅ Better resource utilization
- ✅ Clear audit trail
- ✅ Easier to enforce policies
- ✅ GitOps workflow

### For the Organization
- ✅ Faster time-to-market
- ✅ Reduced costs (vcluster efficiency)
- ✅ Better security (isolation)
- ✅ Compliance (audit trail)
- ✅ Scalability (repeatable patterns)

## Production Considerations (3 minutes)

### What's Different in Production?

**Cluster**:
- KIND → EKS/GKE/AKS
- Multi-AZ for HA
- Auto-scaling node groups

**State Management**:
- Local state → S3/GCS/Azure Storage
- State locking with DynamoDB/GCS
- Encryption at rest

**Security**:
- RBAC and IRSA/Workload Identity
- Network policies
- Pod Security Standards
- Secret management (Vault, SOPS)

**Monitoring**:
- Prometheus + Grafana
- Cost tracking per team
- Resource quotas and limits

**Atlantis**:
- Run in Kubernetes
- Webhook configuration
- GitHub/GitLab integration
- OIDC authentication

### Adding More Services

**Current Demo**:
- PostgreSQL
- Redis

**Production Examples**:
- RDS/CloudSQL databases
- S3/GCS buckets
- Message queues (SQS, Pub/Sub)
- Caching layers
- Service meshes
- Observability stacks

**How to Add**:
1. Create template in `templates/`
2. Teams request via PR
3. Terramate generates stack
4. Atlantis deploys automatically

## Q&A Topics

### Common Questions:

**Q: Why vcluster instead of namespaces?**
A: Stronger isolation, teams can have cluster-admin, custom CRDs, separate API servers

**Q: Does this scale?**
A: Yes! One physical cluster can host 30+ vclusters. Production examples with 100+

**Q: What about costs?**
A: vcluster is more efficient than separate clusters. Track costs per team with tags

**Q: How do teams get credentials?**
A: Kubeconfigs stored securely (Vault), or use OIDC with short-lived tokens

**Q: Can teams deploy anything?**
A: Use OPA/Kyverno for policy enforcement. Platform provides guardrails

**Q: How to handle breaking changes?**
A: Version templates, gradual rollout, terramate helps with bulk updates

## Closing (1 minute)

### Recap
- **tenv**: Consistent versions
- **terramate**: Stack generation
- **terragrunt**: Dependencies
- **atlantis**: GitOps
- **OpenTofu**: Open-source IaC

### Next Steps
1. Try the demo: `./scripts/demo.sh`
2. Customize for your needs
3. Add your service types
4. Integrate with your Git workflow
5. Roll out to teams gradually

### Resources
- Demo repo: [GitHub link]
- OpenTofu: https://opentofu.org
- vcluster: https://www.vcluster.com
- terragrunt: https://terragrunt.gruntwork.io
- terramate: https://terramate.io
- atlantis: https://www.runatlantis.io

---

## Backup Slides / Extra Content

### Dependency Graph

```
KIND Cluster (Layer 1)
    ↓
vcluster (Layer 2)
    ↓
Team Stacks (Layer 3)
```

### Terragrunt DRY Benefits

Before:
- Each stack: 50+ lines of duplicate config
- 10 stacks = 500 lines of duplication
- Changes require updating all files

After:
- Root config: Shared configuration
- Each stack: 10 lines of unique config
- One change propagates to all

### Real-World Use Cases

1. **Startup**: Fast feature development
2. **Enterprise**: Compliance + speed
3. **Agency**: Multi-client isolation
4. **SaaS**: Per-customer environments

### Cost Comparison

Traditional:
- 10 teams × 1 cluster each = 10 clusters
- ~$1,500/month × 10 = $15,000/month

Platform as a Product:
- 1 host cluster + 10 vclusters
- ~$2,500/month
- **83% cost savings**

### Timeline Comparison

Traditional Workflow:
- Request → 2 days
- Approval → 3 days
- Provisioning → 1 day
- **Total: 6 days**

Platform as a Product:
- PR → Auto-plan → Approve → Apply
- **Total: 10 minutes**

---

## Demo Checklist

Before Presentation:
- [ ] Run `./scripts/setup.sh`
- [ ] Verify Docker is running
- [ ] Test internet connection
- [ ] Clear terminal history
- [ ] Prepare backup terminals
- [ ] Have cleanup command ready
- [ ] Test Atlantis (optional)
- [ ] Prepare 2-3 browser tabs

During Demo:
- [ ] Increase terminal font size
- [ ] Use dark theme
- [ ] Clear screen between commands
- [ ] Explain before running
- [ ] Show outputs
- [ ] Point out key details

After Demo:
- [ ] Run cleanup: `./scripts/cleanup.sh`
- [ ] Answer questions
- [ ] Share repo link

