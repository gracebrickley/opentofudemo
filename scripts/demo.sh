#!/bin/bash
set -e

# Full demo script for OpenTofu Platform as a Product
# This script runs through the entire demo workflow

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}===================================="
    echo -e "$1"
    echo -e "====================================${NC}"
    echo ""
}

# Function to pause for user confirmation
pause() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Function to run command with logging
run_cmd() {
    echo -e "${GREEN}Running:${NC} $1"
    eval "$1"
}

print_section "OpenTofu Platform as a Product - Demo"

echo "This demo will:"
echo "  1. Deploy KIND cluster (host Kubernetes)"
echo "  2. Deploy vclusters (virtual clusters for teams)"
echo "  3. Deploy team infrastructure (databases, apps)"
echo "  4. Show how tools work together"
echo ""
echo "Prerequisites: Run ./scripts/setup.sh first"
echo ""

pause

# Step 1: Deploy KIND cluster
print_section "Step 1: Deploy KIND Cluster (Layer 1)"

echo "This creates the host Kubernetes cluster using KIND."
echo "Managed by: OpenTofu + Terragrunt"
echo "Version controlled by: tenv"
echo ""

pause

cd stacks/platform/kind-cluster
run_cmd "terragrunt init"
run_cmd "terragrunt plan"

echo ""
echo "Review the plan above. This will create a KIND cluster."
pause

run_cmd "terragrunt apply -auto-approve"

echo ""
echo -e "${GREEN}✓ KIND cluster deployed successfully!${NC}"
echo ""
echo "Verifying cluster..."

# Set absolute path to kubeconfig
KUBECONFIG_PATH="$(pwd)/kind-kubeconfig"

# Verify kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo -e "${RED}Error: Kubeconfig not found at $KUBECONFIG_PATH${NC}"
    echo "Attempting to export kubeconfig manually..."
    kind export kubeconfig --name opentofu-platform-demo --kubeconfig "$KUBECONFIG_PATH"
fi

export KUBECONFIG="$KUBECONFIG_PATH"
echo "Using KUBECONFIG: $KUBECONFIG"

run_cmd "kubectl cluster-info"
run_cmd "kubectl get nodes"

pause

# Step 2: Deploy vclusters
print_section "Step 2: Deploy Virtual Clusters (Layer 2)"

cd ../vcluster

echo "This deploys isolated virtual clusters for each team."
echo "Managed by: OpenTofu + Terragrunt + Helm"
echo "Dependencies: KIND cluster (managed by terragrunt)"
echo ""

pause

run_cmd "terragrunt init"
run_cmd "terragrunt plan"

echo ""
echo "Review the plan. This will deploy vcluster for team-a and team-b."
pause

run_cmd "terragrunt apply -auto-approve"

echo ""
echo -e "${GREEN}✓ Virtual clusters deployed successfully!${NC}"
echo ""
echo "Verifying vclusters..."
export KUBECONFIG="$(cd ../kind-cluster && pwd)/kind-kubeconfig"
echo "Using KUBECONFIG: $KUBECONFIG"
run_cmd "kubectl get namespaces | grep vcluster"
run_cmd "kubectl get pods -n vcluster-team-a"
run_cmd "kubectl get pods -n vcluster-team-b"

echo ""
echo "Virtual cluster kubeconfigs generated:"
ls -l vcluster-*.kubeconfig 2>/dev/null || echo "  (kubeconfigs will be generated on first access)"

pause

# Step 3: Deploy Team A infrastructure
print_section "Step 3: Deploy Team A Infrastructure (Layer 3)"

cd ../../teams/team-a

echo "This deploys Team A's infrastructure into their virtual cluster."
echo "Includes: Namespace, sample app, PostgreSQL database"
echo "Managed by: OpenTofu + Terragrunt + Helm"
echo "Dependencies: vcluster-team-a (managed by terragrunt)"
echo ""

pause

run_cmd "terragrunt init"
run_cmd "terragrunt plan"

echo ""
echo "Review the plan. This will deploy Team A's infrastructure."
pause

run_cmd "terragrunt apply -auto-approve"

echo ""
echo -e "${GREEN}✓ Team A infrastructure deployed successfully!${NC}"
echo ""
echo "Verifying Team A resources..."
TEAM_A_KUBECONFIG="$(cd ../../platform/vcluster && pwd)/vcluster-team-a.kubeconfig"
if [ -f "$TEAM_A_KUBECONFIG" ]; then
    export KUBECONFIG="$TEAM_A_KUBECONFIG"
    echo "Using KUBECONFIG: $KUBECONFIG"
    run_cmd "kubectl get namespaces"
    run_cmd "kubectl get all -n team-a-apps"
else
    echo -e "${YELLOW}Warning: Team A kubeconfig not found at $TEAM_A_KUBECONFIG${NC}"
fi

pause

# Step 4: Deploy Team B infrastructure
print_section "Step 4: Deploy Team B Infrastructure (Layer 3)"

cd ../team-b

echo "This deploys Team B's infrastructure into their virtual cluster."
echo "Includes: Namespace, sample app, Redis cache"
echo "Managed by: OpenTofu + Terragrunt + Helm"
echo "Dependencies: vcluster-team-b (managed by terragrunt)"
echo ""

pause

run_cmd "terragrunt init"
run_cmd "terragrunt plan"

echo ""
echo "Review the plan. This will deploy Team B's infrastructure."
pause

run_cmd "terragrunt apply -auto-approve"

echo ""
echo -e "${GREEN}✓ Team B infrastructure deployed successfully!${NC}"
echo ""
echo "Verifying Team B resources..."
TEAM_B_KUBECONFIG="$(cd ../../platform/vcluster && pwd)/vcluster-team-b.kubeconfig"
if [ -f "$TEAM_B_KUBECONFIG" ]; then
    export KUBECONFIG="$TEAM_B_KUBECONFIG"
    echo "Using KUBECONFIG: $KUBECONFIG"
    run_cmd "kubectl get namespaces"
    run_cmd "kubectl get all -n team-b-apps"
else
    echo -e "${YELLOW}Warning: Team B kubeconfig not found at $TEAM_B_KUBECONFIG${NC}"
fi

pause

# Summary
print_section "Demo Summary"

cd ../../../../

echo -e "${GREEN}Demo completed successfully!${NC}"
echo ""
echo "What we demonstrated:"
echo ""
echo "1. ${BLUE}tenv${NC} - Version Management"
echo "   - Ensured consistent OpenTofu version (1.8.8) across all stacks"
echo "   - Prevents version conflicts between teams"
echo ""
echo "2. ${BLUE}terramate${NC} - Stack Generation"
echo "   - Stack metadata defined in stack.tm.hcl files"
echo "   - Templates available for creating new teams"
echo "   - Try: ./scripts/create-team.sh team-c"
echo ""
echo "3. ${BLUE}terragrunt${NC} - Dependency Management"
echo "   - KIND cluster deployed first (Layer 1)"
echo "   - vclusters deployed after KIND (Layer 2)"
echo "   - Team stacks deployed after vclusters (Layer 3)"
echo "   - Shared configuration in root terragrunt.hcl"
echo ""
echo "4. ${BLUE}atlantis${NC} - GitOps Workflow"
echo "   - Configuration: atlantis.yaml"
echo "   - Run: atlantis server --repo-allowlist='*' --atlantis-url='http://localhost:4141'"
echo "   - Create PR → Atlantis runs plan → Review → Comment 'atlantis apply'"
echo ""
echo "Infrastructure deployed:"
echo "  - 1 KIND cluster (host)"
echo "  - 2 virtual clusters (team-a, team-b)"
echo "  - Team A: nginx app + PostgreSQL"
echo "  - Team B: nginx app + Redis"
echo ""
echo "Explore the infrastructure:"
echo ""
PROJECT_ROOT="$(cd ../../../../ && pwd)"
echo "  # View host cluster"
echo "  export KUBECONFIG=$PROJECT_ROOT/stacks/platform/kind-cluster/kind-kubeconfig"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""
echo "  # View Team A vcluster"
echo "  export KUBECONFIG=$PROJECT_ROOT/stacks/platform/vcluster/vcluster-team-a.kubeconfig"
echo "  kubectl get pods -n team-a-apps"
echo ""
echo "  # View Team B vcluster"
echo "  export KUBECONFIG=$PROJECT_ROOT/stacks/platform/vcluster/vcluster-team-b.kubeconfig"
echo "  kubectl get pods -n team-b-apps"
echo ""
echo "Clean up:"
echo "  ./scripts/cleanup.sh"
echo ""

