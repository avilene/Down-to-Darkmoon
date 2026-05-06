#!/usr/bin/env bash
# Append package/release link summary to GitHub Actions job summary (GITHUB_STEP_SUMMARY).
# Env: TAG

set -euo pipefail

: "${GITHUB_STEP_SUMMARY:?}"
: "${TAG:?}"
: "${GITHUB_SERVER_URL:?}"
: "${GITHUB_REPOSITORY:?}"

REPO_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"
RELEASE_URL="${REPO_URL}/releases/tag/${TAG}"

{
  echo "### Package release"
  echo ""
  echo "- **Tag:** \`${TAG}\`"
  echo "- **GitHub release:** [${TAG}](${RELEASE_URL})"
} >> "$GITHUB_STEP_SUMMARY"
