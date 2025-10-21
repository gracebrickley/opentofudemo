#!/bin/bash
set -e

# Script to create a new team stack using terramate
# Usage: ./scripts/create-team.sh <team-name>

if [ $# -eq 0 ]; then
    echo "Error: Team name is required"
    echo "Usage: $0 <team-name>"
    echo "Example: $0 team-c"
    exit 1
fi

TEAM_NAME=$1
TEAM_DIR="stacks/teams/${TEAM_NAME}"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "===================================="
echo "Creating new team stack: ${TEAM_NAME}"
echo "===================================="
echo ""

# Check if team already exists
if [ -d "$TEAM_DIR" ]; then
    echo -e "${RED}Error: Team directory already exists: $TEAM_DIR${NC}"
    exit 1
fi

# Create team directory
echo "Creating team directory..."
mkdir -p "$TEAM_DIR"

# Copy template files and substitute team name
echo "Generating stack from template..."

# Copy main.tf
cat templates/team-stack/main.tf.tmpl | sed "s/\${global.team_name}/${TEAM_NAME}/g" > "$TEAM_DIR/main.tf"

# Copy outputs.tf
cat templates/team-stack/outputs.tf.tmpl | sed "s/\${global.team_name}/${TEAM_NAME}/g" > "$TEAM_DIR/outputs.tf"

# Copy terragrunt.hcl
cat templates/team-stack/terragrunt.hcl.tmpl | sed "s/\${global.team_name}/${TEAM_NAME}/g" > "$TEAM_DIR/terragrunt.hcl"

# Create stack.tm.hcl
cat > "$TEAM_DIR/stack.tm.hcl" <<EOF
# Terramate stack metadata for ${TEAM_NAME}

stack {
  name        = "$(echo ${TEAM_NAME} | sed 's/.*/\u&/') Stack"
  description = "Infrastructure stack for ${TEAM_NAME}"
  tags        = ["team", "application", "${TEAM_NAME}", "layer-3"]
  id          = "teams/${TEAM_NAME}"
  after       = ["platform/vcluster"]
}
EOF

echo -e "${GREEN}✓${NC} Stack files created in $TEAM_DIR"
echo ""

# Update vcluster configuration
echo "Updating vcluster configuration..."
VCLUSTER_CONFIG="stacks/platform/vcluster/terragrunt.hcl"

# Add the new team to vcluster inputs
if ! grep -q "\"${TEAM_NAME}\"" "$VCLUSTER_CONFIG"; then
    # This is a simple approach - in production, you'd use a more robust method
    echo -e "${YELLOW}⚠${NC} Please manually add ${TEAM_NAME} to vcluster configuration:"
    echo "   File: $VCLUSTER_CONFIG"
    echo "   Add to vclusters input:"
    echo ""
    echo "   ${TEAM_NAME} = {"
    echo "     namespace    = \"vcluster-${TEAM_NAME}\""
    echo "     release_name = \"vcluster-${TEAM_NAME}\""
    echo "   }"
    echo ""
fi

# Update Atlantis configuration
echo "Updating Atlantis configuration..."
ATLANTIS_CONFIG="atlantis.yaml"

if ! grep -q "teams-${TEAM_NAME}" "$ATLANTIS_CONFIG"; then
    echo -e "${YELLOW}⚠${NC} Please manually add ${TEAM_NAME} to Atlantis configuration:"
    echo "   File: $ATLANTIS_CONFIG"
    echo "   Add a new project entry under 'projects:'"
    echo ""
    echo "  - name: teams-${TEAM_NAME}"
    echo "    dir: stacks/teams/${TEAM_NAME}"
    echo "    workspace: default"
    echo "    terraform_version: v1.8.8"
    echo "    autoplan:"
    echo "      when_modified:"
    echo "        - \"*.tf\""
    echo "        - \"*.hcl\""
    echo "      enabled: true"
    echo "    apply_requirements:"
    echo "      - approved"
    echo "      - mergeable"
    echo "    workflow: terragrunt"
    echo ""
fi

echo ""
echo "===================================="
echo -e "${GREEN}Team stack created successfully!${NC}"
echo "===================================="
echo ""
echo "Stack location: $TEAM_DIR"
echo ""
echo "Next steps:"
echo "  1. Review and customize the stack configuration"
echo "  2. Update vcluster config to include ${TEAM_NAME}"
echo "  3. Deploy vcluster: cd stacks/platform/vcluster && terragrunt apply"
echo "  4. Deploy team stack: cd $TEAM_DIR && terragrunt apply"
echo ""
echo "Or commit and push to trigger Atlantis workflow:"
echo "  git add $TEAM_DIR"
echo "  git commit -m \"Add ${TEAM_NAME} stack\""
echo "  git push"
echo ""

