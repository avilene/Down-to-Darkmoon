#!/usr/bin/env bash
# Append bump/tag summary to GitHub Actions job summary (GITHUB_STEP_SUMMARY).
# Env: BUMP, OUT_VERSION, OUT_TAG, OUT_PREVIOUS

set -euo pipefail

: "${GITHUB_STEP_SUMMARY:?}"
: "${BUMP:?}"
: "${OUT_VERSION:?}"
: "${OUT_TAG:?}"
: "${OUT_PREVIOUS:?}"

if [[ "${BUMP}" == "skip" ]]; then
  {
    echo "### Release from existing TOC version"
    echo ""
    echo "- **TOC version:** ${OUT_VERSION}"
    echo "- **Tag:** \`${OUT_TAG}\`"
  } >> "$GITHUB_STEP_SUMMARY"
else
  {
    echo "### Version bump"
    echo ""
    echo "- **Previous:** ${OUT_PREVIOUS}"
    echo "- **New:** ${OUT_VERSION}"
    echo "- **Tag:** \`${OUT_TAG}\`"
  } >> "$GITHUB_STEP_SUMMARY"
fi
