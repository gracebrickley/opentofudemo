# Terramate stack metadata for team template
# This template is used to generate new team stacks

stack {
  name        = "Team ${tm_try(global.team_name, "unknown")} Stack"
  description = "Infrastructure stack for ${tm_try(global.team_name, "unknown")}"
  tags        = ["team", "application", "layer-3"]
  id          = "teams/${tm_try(global.team_name, "unknown")}"
}

# Globals specific to this template
globals {
  team_name = tm_try(global.team_name, "new-team")
}

