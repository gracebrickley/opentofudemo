# Terramate stack metadata for Team A

stack {
  name        = "Team A Stack"
  description = "Infrastructure stack for Team A"
  tags        = ["team", "application", "team-a", "layer-3"]
  id          = "teams/team-a"
  after       = ["platform/vcluster"]
}

