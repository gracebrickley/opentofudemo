#!/bin/bash
# Script to start Atlantis server for local demo
# This script helps set up and run Atlantis with proper authentication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🌊 Starting Atlantis Server"
echo ""

# Check if GitHub credentials are provided
if [ -z "$ATLANTIS_GH_USER" ] || [ -z "$ATLANTIS_GH_TOKEN" ]; then
    echo "⚠️  GitHub credentials not found in environment variables."
    echo ""
    echo "To set up GitHub authentication:"
    echo ""
    echo "1. Go to: https://github.com/settings/tokens/new"
    echo "2. Generate a token with 'repo' scope"
    echo "3. Set environment variables:"
    echo ""
    echo "   export ATLANTIS_GH_USER='your-github-username'"
    echo "   export ATLANTIS_GH_TOKEN='your-github-token'"
    echo ""
    echo "Then run this script again."
    echo ""
    
    # Prompt user if they want to enter credentials now
    read -p "Do you want to enter credentials now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "GitHub username: " gh_user
        read -sp "GitHub token: " gh_token
        echo
        export ATLANTIS_GH_USER="$gh_user"
        export ATLANTIS_GH_TOKEN="$gh_token"
        echo "✅ Credentials set for this session"
    else
        exit 1
    fi
fi

# Set defaults
ATLANTIS_URL="${ATLANTIS_URL:-http://localhost:4141}"
ATLANTIS_PORT="${ATLANTIS_PORT:-4141}"
REPO_ALLOWLIST="${REPO_ALLOWLIST:-*}"

echo "Configuration:"
echo "  - User: $ATLANTIS_GH_USER"
echo "  - URL: $ATLANTIS_URL"
echo "  - Port: $ATLANTIS_PORT"
echo "  - Repo Allowlist: $REPO_ALLOWLIST"
echo ""

# Change to repo root
cd "$ROOT_DIR"

# Check if atlantis is installed
if ! command -v atlantis &> /dev/null; then
    echo "❌ Atlantis is not installed."
    echo ""
    echo "Install with: brew install atlantis"
    echo "Or download from: https://www.runatlantis.io/docs/installation-guide.html"
    exit 1
fi

# Ensure kubeconfigs are set up for vcluster access
echo "🔧 Ensuring vcluster kubeconfigs are ready..."
if [ -f "$ROOT_DIR/scripts/setup-vcluster-kubeconfigs.sh" ]; then
    bash "$ROOT_DIR/scripts/setup-vcluster-kubeconfigs.sh"
fi

echo ""
echo "🚀 Starting Atlantis server..."
echo ""
echo "📝 Atlantis will be available at: $ATLANTIS_URL"
echo ""
echo "To use Atlantis in a PR workflow:"
echo "  1. Create a branch: git checkout -b my-feature"
echo "  2. Make changes to infrastructure"
echo "  3. Commit and push: git push origin my-feature"
echo "  4. Create a PR on GitHub"
echo "  5. Atlantis will automatically run 'plan'"
echo "  6. Review and comment 'atlantis apply' to apply"
echo ""
echo "Press Ctrl+C to stop Atlantis"
echo ""

# Set environment variables for OpenTofu
export ATLANTIS_DEFAULT_TF_VERSION="1.8.8"
export PATH="$PATH:/opt/homebrew/bin"

# Create a symbolic link so Atlantis can find tofu as terraform
# (Some versions of Atlantis have issues with --executable-name)
TEMP_BIN_DIR="$ROOT_DIR/.atlantis/bin"
mkdir -p "$TEMP_BIN_DIR"
if [ ! -f "$TEMP_BIN_DIR/terraform" ]; then
    ln -sf "$(which tofu)" "$TEMP_BIN_DIR/terraform"
    echo "✓ Created terraform -> tofu symlink at $TEMP_BIN_DIR/terraform"
fi
export PATH="$TEMP_BIN_DIR:$PATH"

# Start Atlantis with OpenTofu
atlantis server \
  --atlantis-url="$ATLANTIS_URL" \
  --port="$ATLANTIS_PORT" \
  --repo-allowlist="$REPO_ALLOWLIST" \
  --gh-user="$ATLANTIS_GH_USER" \
  --gh-token="$ATLANTIS_GH_TOKEN" \
  --repo-config="$ROOT_DIR/atlantis-repos.yaml" \
  --data-dir="$ROOT_DIR/.atlantis" \
  --log-level="info" \
  --default-tf-version="1.8.8"

