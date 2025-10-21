# Demo Script - Quick Reference

Use this as a cheat sheet during live demos.

## Pre-Demo Checklist

```bash
☐ Docker Desktop running
☐ Terminal font size increased
☐ Terminal cleared: clear
☐ In project directory: cd opentofudemo
☐ Setup completed: ./scripts/setup.sh
☐ Backup terminal window ready
```

## Demo Flow (15 minutes)

### 1. Introduction (2 min)

**Say**:
> "Today I'm showing how tenv, terramate, terragrunt, and atlantis work together with OpenTofu to build a Platform as a Product. Teams can self-service infrastructure in minutes instead of days."

**Show**: Architecture diagram in README.md or ARCHITECTURE.md

### 2. Show Project Structure (2 min)

```bash
# Show clean structure
tree -L 2 stacks/

# Explain layers
echo "Layer 1: KIND cluster (foundation)"
echo "Layer 2: vclusters (isolation)"
echo "Layer 3: Team resources (apps/databases)"
```

**Say**:
> "Three layers: KIND provides the host, vcluster provides isolation per team, and team stacks deploy their infrastructure."

### 3. Version Management (1 min)

```bash
# Show tenv in action
cat .tenv.tofu.version
tenv tofu list
tofu version
```

**Say**:
> "tenv ensures everyone uses OpenTofu 1.8.8. No version conflicts, automatic installation."

### 4. Deploy Platform (4 min)

```bash
# Layer 1: KIND
cd stacks/platform/kind-cluster
terragrunt plan
terragrunt apply -auto-approve

# Verify
export KUBECONFIG=$(pwd)/kind-kubeconfig
kubectl get nodes
kubectl get pods -A
```

**Say**:
> "KIND creates our host cluster. In production, this would be EKS, GKE, or AKS. Takes about 2 minutes."

```bash
# Layer 2: vcluster
cd ../vcluster
terragrunt plan

# Point out dependency
cat terragrunt.hcl | grep -A 5 "dependency"
```

**Say**:
> "Notice terragrunt automatically resolves the KIND dependency. It passes the kubeconfig from Layer 1 to Layer 2."

```bash
terragrunt apply -auto-approve

# Verify
export KUBECONFIG=../kind-cluster/kind-kubeconfig
kubectl get pods -A | grep vcluster
```

**Say**:
> "Two vclusters deployed - one for team-a, one for team-b. Each team gets their own isolated Kubernetes cluster."

### 5. Deploy Team Infrastructure (3 min)

```bash
# Team A
cd ../../teams/team-a
cat terragrunt.hcl | grep -A 5 "dependency"
```

**Say**:
> "Team A depends on vcluster. Terragrunt passes the team-specific kubeconfig automatically."

```bash
terragrunt apply -auto-approve

# Verify
export KUBECONFIG=../../platform/vcluster/vcluster-team-a.kubeconfig
kubectl get all -n team-a-apps
kubectl get secret -n team-a-apps team-a-db-credentials
```

**Say**:
> "Team A now has nginx app and PostgreSQL database in their own isolated cluster."

### 6. Show Isolation (2 min)

```bash
# Team B resources
export KUBECONFIG=../../platform/vcluster/vcluster-team-b.kubeconfig
kubectl get namespaces
kubectl get pods -A
```

**Say**:
> "Team B has completely different resources - Redis instead of PostgreSQL. They can't see Team A's resources at all. Complete isolation."

```bash
# Try to access Team A namespace from Team B
kubectl get pods -n team-a-apps
# Shows: Error or not found
```

**Say**:
> "Team B can't see Team A's namespace. Strong security boundary."

### 7. Terramate Demo (2 min)

```bash
# Show stack metadata
cd ../../../
terramate list

# Create new team
./scripts/create-team.sh team-c
ls -la stacks/teams/team-c/
cat stacks/teams/team-c/stack.tm.hcl
```

**Say**:
> "Terramate generated a complete stack from template in seconds. Consistent structure, ready to customize and deploy."

### 8. Atlantis Workflow (1 min)

**Show**: atlantis.yaml file

```bash
cat atlantis.yaml | head -30
```

**Say**:
> "In production, all changes go through pull requests. Developer creates PR, Atlantis runs plan automatically, team reviews, then applies. Complete audit trail in Git history."

**Optional**: Start Atlantis if time permits
```bash
atlantis server --repo-allowlist='*' --atlantis-url="http://localhost:4141" &
# Open http://localhost:4141
```

### 9. Wrap Up (1 min)

**Say**:
> "Let's recap:
> - **tenv**: Everyone uses OpenTofu 1.8.8
> - **terramate**: Generate teams from templates
> - **terragrunt**: Manage dependencies automatically
> - **atlantis**: GitOps workflow for safety
> - **Result**: Self-service infrastructure in minutes"

```bash
# Show everything running
export KUBECONFIG=stacks/platform/kind-cluster/kind-kubeconfig
kubectl get pods -A
```

## Post-Demo Q&A Prep

### Common Questions

**Q: Why vcluster vs namespaces?**
A: Stronger isolation, teams get cluster-admin in their vcluster, separate API servers, custom CRDs.

**Q: Performance overhead?**
A: Minimal - vcluster is lightweight. Syncs only needed resources to host cluster.

**Q: Production scale?**
A: Single host cluster can support 30+ vclusters, tested with 100+.

**Q: Cost savings?**
A: 70-85% compared to dedicated clusters per team.

**Q: How to add services?**
A: Create template, teams request via PR, terramate generates, atlantis deploys.

**Q: Security?**
A: Network policies, RBAC, OIDC, pod security standards in production.

## Cleanup After Demo

```bash
# If you need to reset
./scripts/cleanup.sh

# Verify clean
kind get clusters
docker ps | grep kind
```

## Backup Commands

If something fails during demo:

```bash
# Skip to next section
cd /path/to/next/stack

# Show pre-built environment
export KUBECONFIG=stacks/platform/vcluster/vcluster-team-a.kubeconfig
kubectl get all -A

# Restart from clean slate
./scripts/cleanup.sh
./scripts/demo.sh
```

## Time Checkpoints

- 2 min: Done with intro
- 4 min: Done with project structure
- 8 min: KIND deployed
- 11 min: vcluster deployed
- 14 min: Teams deployed
- 15 min: Wrap up

## Success Metrics

After demo, audience should understand:
- ✅ How layers depend on each other
- ✅ How terragrunt manages dependencies
- ✅ How teams are isolated
- ✅ How to add new teams
- ✅ How GitOps workflow works

## Pro Tips

1. **Slow down** - Let commands complete before moving on
2. **Explain first** - Say what you'll do before doing it
3. **Show outputs** - Point out key details in command outputs
4. **Use color** - Highlight important info
5. **Have backup** - Pre-deploy in separate terminal if needed
6. **Engage audience** - Ask "Any questions so far?"

## Demo Variants

### Quick Demo (5 min)
- Show architecture
- Run automated demo script
- Show results
- Q&A

### Deep Dive (30 min)
- Explain each tool
- Show all configurations
- Deploy step by step
- Show isolation
- Create new team
- Atlantis workflow
- Production considerations

### Workshop (2 hours)
- Attendees follow along
- Deploy on their machines
- Customize configurations
- Add new services
- Practice GitOps workflow
- Production migration planning

