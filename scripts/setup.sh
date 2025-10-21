#!/bin/bash
set -e

# Setup script for OpenTofu Platform as a Product Demo
# This script verifies prerequisites and initializes the environment

echo "===================================="
echo "OpenTofu Platform Demo - Setup"
echo "===================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Check prerequisites
echo "Checking prerequisites..."
echo ""

MISSING_TOOLS=0

# Check tenv
if command_exists tenv; then
    print_status 0 "tenv is installed"
else
    print_status 1 "tenv is NOT installed"
    echo "  Install with: brew install tenv"
    MISSING_TOOLS=1
fi

# Check terramate
if command_exists terramate; then
    print_status 0 "terramate is installed"
else
    print_status 1 "terramate is NOT installed"
    echo "  Install with: brew install terramate"
    MISSING_TOOLS=1
fi

# Check terragrunt
if command_exists terragrunt; then
    print_status 0 "terragrunt is installed"
else
    print_status 1 "terragrunt is NOT installed"
    echo "  Install with: brew install terragrunt"
    MISSING_TOOLS=1
fi

# Check KIND
if command_exists kind; then
    print_status 0 "kind is installed"
else
    print_status 1 "kind is NOT installed"
    echo "  Install with: brew install kind"
    MISSING_TOOLS=1
fi

# Check kubectl
if command_exists kubectl; then
    print_status 0 "kubectl is installed"
else
    print_status 1 "kubectl is NOT installed"
    echo "  Install with: brew install kubectl"
    MISSING_TOOLS=1
fi

# Check helm
if command_exists helm; then
    print_status 0 "helm is installed"
else
    print_status 1 "helm is NOT installed"
    echo "  Install with: brew install helm"
    MISSING_TOOLS=1
fi

# Check Docker
if command_exists docker; then
    if docker ps >/dev/null 2>&1; then
        print_status 0 "docker is running"
    else
        print_status 1 "docker is installed but NOT running"
        echo "  Please start Docker Desktop"
        MISSING_TOOLS=1
    fi
else
    print_status 1 "docker is NOT installed"
    echo "  Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    MISSING_TOOLS=1
fi

# Check atlantis (optional)
if command_exists atlantis; then
    print_status 0 "atlantis is installed (optional)"
else
    echo -e "${YELLOW}⚠${NC} atlantis is NOT installed (optional)"
    echo "  Install with: brew install atlantis"
fi

echo ""

# Exit if missing required tools
if [ $MISSING_TOOLS -eq 1 ]; then
    echo -e "${RED}Error: Missing required tools. Please install them and run this script again.${NC}"
    exit 1
fi

echo -e "${GREEN}All prerequisites are installed!${NC}"
echo ""

# Install OpenTofu using tenv
echo "Installing OpenTofu using tenv..."
if [ -f .tenv.tofu.version ]; then
    VERSION=$(cat .tenv.tofu.version)
    echo "Installing OpenTofu version: $VERSION"
    tenv tofu install $VERSION
    tenv tofu use $VERSION
    print_status 0 "OpenTofu $VERSION installed"
else
    echo "Installing latest OpenTofu version..."
    tenv tofu install latest
    tenv tofu use latest
    print_status 0 "OpenTofu installed"
fi

echo ""

# Create state directory
echo "Creating state directory..."
mkdir -p .terraform-state
print_status 0 "State directory created"

echo ""

# Initialize terramate
echo "Initializing terramate..."
if [ -f terramate.tm.hcl ]; then
    # List stacks
    echo "Available stacks:"
    terramate list || echo "  (terramate list command not available in this version)"
    print_status 0 "Terramate initialized"
fi

echo ""

# Add helm repositories
echo "Adding helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo add loft https://charts.loft.sh >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
print_status 0 "Helm repositories added"

echo ""
echo "===================================="
echo -e "${GREEN}Setup completed successfully!${NC}"
echo "===================================="
echo ""
echo "Next steps:"
echo "  1. Deploy the platform: cd stacks/platform/kind-cluster && terragrunt apply"
echo "  2. Deploy vclusters:    cd ../vcluster && terragrunt apply"
echo "  3. Deploy team stacks:  cd ../../teams/team-a && terragrunt apply"
echo ""
echo "Or run the full demo:"
echo "  ./scripts/demo.sh"
echo ""

