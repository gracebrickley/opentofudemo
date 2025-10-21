terramate {
  config {
    # Disable telemetry for demo purposes
    disable_telemetry = true
    
    # Enable experiments if needed
    experiments = []
  }
}

# Global tags that apply to all stacks
globals {
  project = "opentofu-platform-demo"
  managed_by = "terramate"
  platform = "kubernetes"
}

