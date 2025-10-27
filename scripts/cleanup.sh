#!/bin/bash
set -e

# Cleanup script for OpenTofu Platform as a Product Demo
# This script destroys all infrastructure in the correct order

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "===================================="
echo "OpenTofu Platform Demo - Cleanup"
echo "===================================="
echo ""
echo -e "${RED}WARNING: This will destroy all infrastructure!${NC}"
echo ""
echo "This includes:"
echo "  - Team A infrastructure (PostgreSQL, apps)"
echo "  - Team B infrastructure (Redis, apps)"
echo "  - Virtual clusters (team-a, team-b)"
echo "  - KIND cluster"
echo ""
echo -e "${YELLOW}Are you sure you want to continue? (yes/no)${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# Function to destroy stack
destroy_stack() {
    local stack_path=$1
    local stack_name=$2
    
    echo ""
    echo "Destroying: $stack_name"
    echo "Path: $stack_path"
    
    if [ -d "$stack_path" ]; then
        cd "$stack_path"
        if [ -f "terragrunt.hcl" ]; then
            echo "Running terragrunt destroy..."
            terragrunt destroy -auto-approve || {
                echo -e "${RED}Warning: Failed to destroy $stack_name${NC}"
                echo "Continuing with cleanup..."
            }
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}Stack not found, skipping: $stack_path${NC}"
    fi
}

# Store original directory
ORIGINAL_DIR=$(pwd)

# Layer 3: Destroy team infrastructure first
echo "===================================="
echo "Layer 3: Team Infrastructure"
echo "===================================="

destroy_stack "stacks/teams/team-a" "Team A"
destroy_stack "stacks/teams/team-b" "Team B"

# Check for other team stacks
for team_dir in stacks/teams/*/; do
    if [ -d "$team_dir" ] && [ "$team_dir" != "stacks/teams/team-a/" ] && [ "$team_dir" != "stacks/teams/team-b/" ]; then
        team_name=$(basename "$team_dir")
        destroy_stack "$team_dir" "Team $team_name"
    fi
done

# Layer 2: Destroy vclusters
echo ""
echo "===================================="
echo "Layer 2: Virtual Clusters"
echo "===================================="

destroy_stack "stacks/platform/vcluster" "vclusters"

# Layer 1: Destroy KIND cluster
echo ""
echo "===================================="
echo "Layer 1: KIND Cluster"
echo "===================================="

destroy_stack "stacks/platform/kind-cluster" "KIND cluster"

# Additional cleanup - ensure KIND cluster is really gone
echo ""
echo "Ensuring KIND cluster is deleted..."
if command -v kind >/dev/null 2>&1; then
    kind delete cluster --name opentofu-platform-demo 2>/dev/null || true
fi

# Clean up generated files
echo ""
echo "Cleaning up generated files..."

# Remove kubeconfig files
rm -f stacks/platform/kind-cluster/kind-kubeconfig
rm -f stacks/platform/kind-cluster/kind-config.yaml
rm -f stacks/platform/vcluster/vcluster-*.kubeconfig
rm -f stacks/platform/vcluster/vcluster-*-clean.kubeconfig
rm -f stacks/platform/vcluster/vcluster  # Remove local vcluster CLI binary

# Remove terraform state files
echo "Removing local state files..."
rm -rf .terraform-state/

# Remove .terraform directories
echo "Removing .terraform directories..."
find stacks -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true

# Remove .terragrunt-cache directories
echo "Removing .terragrunt-cache directories..."
find stacks -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true

# Remove generated files
echo "Removing generated files..."
find stacks -type f -name "backend.tf" -delete 2>/dev/null || true
find stacks -type f -name "versions_generated.tf" -delete 2>/dev/null || true
find stacks -type f -name "provider_generated.tf" -delete 2>/dev/null || true
find stacks -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
find stacks -type f -name ".terraform-initialized" -delete 2>/dev/null || true

cd "$ORIGINAL_DIR"

echo ""
echo "===================================="
echo -e "${GREEN}Cleanup completed!${NC}"
echo "===================================="
echo ""
echo "All infrastructure has been destroyed."
echo ""
echo "To run the demo again:"
echo "  ./scripts/demo.sh"
echo ""

