# Terramate stack metadata for vcluster

stack {
  name        = "Virtual Clusters"
  description = "Virtual clusters for team isolation using vcluster"
  tags        = ["platform", "vcluster", "kubernetes", "layer-2"]
  id          = "platform/vcluster"
  after       = ["platform/kind-cluster"]
}

