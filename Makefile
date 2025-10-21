.PHONY: help setup demo clean verify tools check-tools kind vcluster teams team-a team-b atlantis create-team list status

# Default target
.DEFAULT_GOAL := help

# Variables
SCRIPTS_DIR := scripts
KIND_DIR := stacks/platform/kind-cluster
VCLUSTER_DIR := stacks/platform/vcluster
TEAM_A_DIR := stacks/teams/team-a
TEAM_B_DIR := stacks/teams/team-b

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "OpenTofu Platform as a Product Demo"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup     # Install prerequisites and setup environment"
	@echo "  make demo      # Run full demo"
	@echo "  make clean     # Clean up all resources"

check-tools: ## Check if required tools are installed
	@echo "Checking required tools..."
	@command -v tenv >/dev/null 2>&1 || (echo "❌ tenv not found" && exit 1)
	@command -v terramate >/dev/null 2>&1 || (echo "❌ terramate not found" && exit 1)
	@command -v terragrunt >/dev/null 2>&1 || (echo "❌ terragrunt not found" && exit 1)
	@command -v kind >/dev/null 2>&1 || (echo "❌ kind not found" && exit 1)
	@command -v kubectl >/dev/null 2>&1 || (echo "❌ kubectl not found" && exit 1)
	@command -v helm >/dev/null 2>&1 || (echo "❌ helm not found" && exit 1)
	@command -v docker >/dev/null 2>&1 || (echo "❌ docker not found" && exit 1)
	@docker ps >/dev/null 2>&1 || (echo "❌ docker not running" && exit 1)
	@echo "✅ All required tools are installed!"

tools: ## Install required tools (macOS with Homebrew)
	@echo "Installing required tools..."
	brew install tenv terramate terragrunt kind kubectl helm
	@echo "✅ Tools installed!"
	@echo ""
	@echo "Note: Ensure Docker Desktop is installed and running"

setup: check-tools ## Setup environment and verify prerequisites
	@echo "Running setup script..."
	@$(SCRIPTS_DIR)/setup.sh

demo: ## Run the full demo
	@echo "Running full demo..."
	@$(SCRIPTS_DIR)/demo.sh

kind: ## Deploy KIND cluster (Layer 1)
	@echo "Deploying KIND cluster..."
	cd $(KIND_DIR) && terragrunt init && terragrunt apply -auto-approve
	@echo "✅ KIND cluster deployed!"

vcluster: kind ## Deploy vclusters (Layer 2)
	@echo "Deploying vclusters..."
	cd $(VCLUSTER_DIR) && terragrunt init && terragrunt apply -auto-approve
	@echo "✅ vclusters deployed!"

team-a: vcluster ## Deploy Team A infrastructure
	@echo "Deploying Team A infrastructure..."
	cd $(TEAM_A_DIR) && terragrunt init && terragrunt apply -auto-approve
	@echo "✅ Team A deployed!"

team-b: vcluster ## Deploy Team B infrastructure
	@echo "Deploying Team B infrastructure..."
	cd $(TEAM_B_DIR) && terragrunt init && terragrunt apply -auto-approve
	@echo "✅ Team B deployed!"

teams: team-a team-b ## Deploy all team infrastructure

all: kind vcluster teams ## Deploy everything (KIND + vclusters + teams)

create-team: ## Create a new team stack (usage: make create-team TEAM=team-c)
ifndef TEAM
	@echo "Error: TEAM variable is required"
	@echo "Usage: make create-team TEAM=team-c"
	@exit 1
endif
	@echo "Creating team: $(TEAM)"
	@$(SCRIPTS_DIR)/create-team.sh $(TEAM)

list: ## List all terramate stacks
	@echo "Available stacks:"
	@terramate list

status: ## Show status of all resources
	@echo "Cluster Status:"
	@echo "==============="
	@kind get clusters 2>/dev/null || echo "No KIND clusters"
	@echo ""
	@if [ -f "$(KIND_DIR)/kind-kubeconfig" ]; then \
		echo "KIND Cluster Nodes:"; \
		export KUBECONFIG=$(KIND_DIR)/kind-kubeconfig && kubectl get nodes 2>/dev/null || echo "Cluster not ready"; \
		echo ""; \
		echo "vclusters:"; \
		export KUBECONFIG=$(KIND_DIR)/kind-kubeconfig && kubectl get pods -A | grep vcluster || echo "No vclusters"; \
	else \
		echo "KIND cluster not deployed"; \
	fi

verify: ## Verify all deployments
	@echo "Verifying deployments..."
	@echo ""
	@echo "1. KIND Cluster:"
	@kind get clusters | grep -q "opentofu-platform-demo" && echo "✅ EXISTS" || echo "❌ NOT FOUND"
	@echo ""
	@echo "2. vclusters:"
	@export KUBECONFIG=$(KIND_DIR)/kind-kubeconfig && \
		kubectl get pods -n vcluster-team-a -o wide 2>/dev/null | grep -q Running && echo "✅ team-a: RUNNING" || echo "❌ team-a: NOT RUNNING"
	@export KUBECONFIG=$(KIND_DIR)/kind-kubeconfig && \
		kubectl get pods -n vcluster-team-b -o wide 2>/dev/null | grep -q Running && echo "✅ team-b: RUNNING" || echo "❌ team-b: NOT RUNNING"
	@echo ""
	@echo "3. Team Resources:"
	@if [ -f "$(VCLUSTER_DIR)/vcluster-team-a.kubeconfig" ]; then \
		export KUBECONFIG=$(VCLUSTER_DIR)/vcluster-team-a.kubeconfig && \
		kubectl get pods -n team-a-apps 2>/dev/null | tail -n +2 | wc -l | xargs echo "Team A pods:"; \
	else \
		echo "Team A: kubeconfig not found"; \
	fi
	@if [ -f "$(VCLUSTER_DIR)/vcluster-team-b.kubeconfig" ]; then \
		export KUBECONFIG=$(VCLUSTER_DIR)/vcluster-team-b.kubeconfig && \
		kubectl get pods -n team-b-apps 2>/dev/null | tail -n +2 | wc -l | xargs echo "Team B pods:"; \
	else \
		echo "Team B: kubeconfig not found"; \
	fi

atlantis: ## Start Atlantis server
	@echo "Starting Atlantis server..."
	@echo "Access at: http://localhost:4141"
	atlantis server --repo-allowlist='*' --atlantis-url="http://localhost:4141"

clean: ## Clean up all resources
	@echo "Cleaning up all resources..."
	@$(SCRIPTS_DIR)/cleanup.sh

plan-all: ## Run terragrunt plan across all stacks
	@echo "Planning all stacks..."
	cd $(KIND_DIR) && terragrunt plan
	cd $(VCLUSTER_DIR) && terragrunt plan
	cd $(TEAM_A_DIR) && terragrunt plan
	cd $(TEAM_B_DIR) && terragrunt plan

init-all: ## Run terragrunt init across all stacks
	@echo "Initializing all stacks..."
	cd $(KIND_DIR) && terragrunt init -upgrade
	cd $(VCLUSTER_DIR) && terragrunt init -upgrade
	cd $(TEAM_A_DIR) && terragrunt init -upgrade
	cd $(TEAM_B_DIR) && terragrunt init -upgrade

clean-cache: ## Clean terragrunt cache
	@echo "Cleaning terragrunt cache..."
	find stacks -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Cache cleaned!"

logs-kind: ## Show KIND cluster logs
	@echo "KIND cluster logs:"
	kind export logs

logs-team-a: ## Show Team A pod logs
	@echo "Team A logs:"
	@export KUBECONFIG=$(VCLUSTER_DIR)/vcluster-team-a.kubeconfig && \
		kubectl logs -n team-a-apps -l app=sample-app --tail=50

logs-team-b: ## Show Team B pod logs
	@echo "Team B logs:"
	@export KUBECONFIG=$(VCLUSTER_DIR)/vcluster-team-b.kubeconfig && \
		kubectl logs -n team-b-apps -l app=sample-app --tail=50

shell-kind: ## Open shell with KIND kubeconfig
	@echo "Opening shell with KIND cluster access..."
	@echo "Run: kubectl get nodes"
	@export KUBECONFIG=$(KIND_DIR)/kind-kubeconfig && $$SHELL

shell-team-a: ## Open shell with Team A kubeconfig
	@echo "Opening shell with Team A cluster access..."
	@echo "Run: kubectl get pods -A"
	@export KUBECONFIG=$(VCLUSTER_DIR)/vcluster-team-a.kubeconfig && $$SHELL

shell-team-b: ## Open shell with Team B kubeconfig
	@echo "Opening shell with Team B cluster access..."
	@echo "Run: kubectl get pods -A"
	@export KUBECONFIG=$(VCLUSTER_DIR)/vcluster-team-b.kubeconfig && $$SHELL

