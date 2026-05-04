#!/usr/bin/env bash
# Bump ## Version in a WoW .toc and push commit + tag, or align tag vX.Y.Z with HEAD (bump=skip).
# Used by .github/workflows/release.yml. Expects: BUMP, BRANCH, TOC; writes version/tag/previous to GITHUB_OUTPUT.

set -euo pipefail

TOC="${TOC:-DownToDarkmoon.toc}"
: "${BUMP:?BUMP is required (patch|minor|major|skip)}"
: "${BRANCH:?BRANCH is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

if [[ ! -f "$TOC" ]]; then
  echo "::error::Missing $TOC"
  exit 1
fi

VERSION_LINE=$(grep -m1 '^## Version:' "$TOC") || true
VERSION=$(echo "$VERSION_LINE" | sed 's/^## Version:[[:space:]]*//')
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Invalid or missing ## Version in $TOC (got '${VERSION:-empty}')"
  exit 1
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

if [[ "$BUMP" == "skip" ]]; then
  NEW="${VERSION}"
  TAG="v${NEW}"
  HEAD_SHA=$(git rev-parse HEAD)
  git fetch origin --tags

  if git rev-parse "$TAG" >/dev/null 2>&1; then
    TAG_SHA=$(git rev-parse "${TAG}^{}")
    if [[ "$TAG_SHA" == "$HEAD_SHA" ]]; then
      echo "Tag ${TAG} already points at HEAD; no tag push."
    else
      echo "Moving tag ${TAG} from $(git rev-parse --short "$TAG_SHA") to HEAD $(git rev-parse --short "$HEAD_SHA")"
      git tag -fa "$TAG" -m "Release ${TAG}"
      git push --force origin "$TAG"
      echo "Force-pushed ${TAG} to HEAD."
    fi
  else
    git tag -a "$TAG" -m "Release ${TAG}"
    git push origin "$TAG"
    echo "Created and pushed ${TAG} at HEAD."
  fi

  {
    echo "version=${NEW}"
    echo "tag=${TAG}"
    echo "previous=${VERSION}"
  } >> "$GITHUB_OUTPUT"

  echo "Skip bump: releasing TOC version ${NEW} as ${TAG}"
  exit 0
fi

IFS='.' read -r MA MI PA <<< "$VERSION"
case "$BUMP" in
  major)
    MA=$((MA + 1)); MI=0; PA=0
    ;;
  minor)
    MI=$((MI + 1)); PA=0
    ;;
  patch)
    PA=$((PA + 1))
    ;;
  *)
    echo "::error::Unknown bump: $BUMP"
    exit 1
    ;;
esac
NEW="${MA}.${MI}.${PA}"
TAG="v${NEW}"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "::error::Tag $TAG already exists"
  exit 1
fi

sed -i "s/^## Version:.*$/## Version: ${NEW}/" "$TOC"

git add "$TOC"
if git diff --cached --quiet; then
  echo "::error::No staged changes after bump (unexpected)"
  exit 1
fi

git commit -m "chore: bump version to ${NEW}"
git tag -a "$TAG" -m "Release ${TAG}"

git push origin "$BRANCH"
git push origin "$TAG"

{
  echo "version=${NEW}"
  echo "tag=${TAG}"
  echo "previous=${VERSION}"
} >> "$GITHUB_OUTPUT"

echo "Bumped ${VERSION} → ${NEW}, pushed ${BRANCH} and ${TAG}"
