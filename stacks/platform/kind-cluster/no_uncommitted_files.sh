#!/usr/bin/env bash
# ---------------------------------------------------------------------
# check-git-clean.sh
#
# Verifies that the current Git working directory is clean:
#   - No uncommitted changes (staged or unstaged)
#   - No untracked files
#
# Works on macOS and Linux.
# ---------------------------------------------------------------------

set -euo pipefail

# Ensure we're inside a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ Error: not inside a Git repository."
  exit 1
fi

# Detect uncommitted changes (unstaged or staged)
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  echo "❌ Uncommitted changes detected:"
  git status --short
  exit 1
fi

# Detect untracked files (macOS-safe version)
UNTRACKED="$(git ls-files --others --exclude-standard)"
if [ -n "$UNTRACKED" ]; then
  echo "❌ Untracked files detected:"
  # Use printf for better POSIX compliance (avoids echo issues on macOS)
  printf '%s\n' "$UNTRACKED"
  exit 1
fi

echo "✅ Git working directory is clean."
exit 0
