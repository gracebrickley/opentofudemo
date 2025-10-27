#!/bin/bash
# Script to setup vcluster kubeconfigs and port-forwards
# Run this after deploying the vcluster stack or when kubeconfigs are missing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔧 Setting up vcluster kubeconfigs and port-forwards..."

# Check if KIND cluster is running
if ! docker ps | grep -q "opentofu-platform-demo-control-plane"; then
    echo "❌ KIND cluster is not running. Please start it first."
    exit 1
fi

# Set kubeconfig for host cluster
export KUBECONFIG="$ROOT_DIR/stacks/platform/kind-cluster/kind-kubeconfig"

# Check if vclusters exist
if ! kubectl get namespace vcluster-team-a &>/dev/null; then
    echo "❌ vcluster-team-a namespace not found. Please deploy the vcluster stack first."
    exit 1
fi

# Kill any existing port-forwards
echo "🧹 Cleaning up existing port-forwards..."
pkill -f "kubectl port-forward.*vcluster-team-" || true
sleep 2

# Extract kubeconfig for team-a
echo "📄 Extracting kubeconfig for team-a..."
kubectl get secret vc-vcluster-team-a -n vcluster-team-a -o jsonpath='{.data.config}' 2>/dev/null | \
    base64 -d | \
    sed 's|https://vcluster-team-a.vcluster-team-a|https://127.0.0.1:8443|g' \
    > "$ROOT_DIR/stacks/platform/vcluster/vcluster-team-a.kubeconfig"

# Extract kubeconfig for team-b
echo "📄 Extracting kubeconfig for team-b..."
kubectl get secret vc-vcluster-team-b -n vcluster-team-b -o jsonpath='{.data.config}' 2>/dev/null | \
    base64 -d | \
    sed 's|https://vcluster-team-b.vcluster-team-b|https://127.0.0.1:8444|g' \
    > "$ROOT_DIR/stacks/platform/vcluster/vcluster-team-b.kubeconfig"

# Start port-forwards in background
echo "🔌 Starting port-forwards..."
nohup kubectl port-forward -n vcluster-team-a svc/vcluster-team-a 8443:443 > /tmp/vcluster-team-a-pf.log 2>&1 &
nohup kubectl port-forward -n vcluster-team-b svc/vcluster-team-b 8444:443 > /tmp/vcluster-team-b-pf.log 2>&1 &

# Wait for port-forwards to be ready
echo "⏳ Waiting for port-forwards to be ready..."
sleep 3

# Verify port-forwards are running
if ! pgrep -f "kubectl port-forward.*vcluster-team-a" > /dev/null; then
    echo "❌ Failed to start port-forward for team-a"
    exit 1
fi

if ! pgrep -f "kubectl port-forward.*vcluster-team-b" > /dev/null; then
    echo "❌ Failed to start port-forward for team-b"
    exit 1
fi

# Copy kubeconfigs to terragrunt cache directories if they exist
echo "📋 Copying kubeconfigs to terragrunt cache directories..."
for cache_dir in "$ROOT_DIR"/stacks/teams/team-*/.terragrunt-cache/*/*/*; do
    if [ -d "$cache_dir" ]; then
        mkdir -p "$cache_dir/../../platform/vcluster"
        cp "$ROOT_DIR"/stacks/platform/vcluster/vcluster-*.kubeconfig "$cache_dir/../../platform/vcluster/" 2>/dev/null || true
    fi
done

echo "✅ Setup complete!"
echo ""
echo "Port-forwards running:"
echo "  - team-a: localhost:8443"
echo "  - team-b: localhost:8444"
echo ""
echo "Kubeconfig files:"
echo "  - $ROOT_DIR/stacks/platform/vcluster/vcluster-team-a.kubeconfig"
echo "  - $ROOT_DIR/stacks/platform/vcluster/vcluster-team-b.kubeconfig"
echo ""
echo "💡 If you clear terragrunt cache, run this script again."



