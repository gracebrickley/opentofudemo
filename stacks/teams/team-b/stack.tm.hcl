# Terramate stack metadata for Team B

stack {
  name        = "Team B Stack"
  description = "Infrastructure stack for Team B"
  tags        = ["team", "application", "team-b", "layer-3"]
  id          = "teams/team-b"
  after       = ["platform/vcluster"]
}

