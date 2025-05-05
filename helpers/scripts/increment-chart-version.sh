#!/bin/bash

# requires git, yq

REPO_ROOT=$(git rev-parse --show-toplevel)

# Path to your Chart.yaml
CHART_FILE="${REPO_ROOT}/charts/llm-d/Chart.yaml"

FEATURE_BRANCH=$(git rev-parse --abbrev-ref HEAD)

STASH_RESULT=$(git stash)

git fetch upstream
git checkout main
git merge --ff-only upstream/main

git switch ${FEATURE_BRANCH}
if [[ "${STASH_RESULT}" != "No local changes to save" ]]; then
  git stash pop
fi;

git checkout main -- ${CHART_FILE}

current_version=$(yq e '.version' "$CHART_FILE")

IFS='.' read -r major minor patch <<< "$current_version"

if [[ "$patch" -lt 9 ]]; then
  patch=$((patch + 1))
else
  patch=0
  if [[ "$minor" -lt 9 ]]; then
    minor=$((minor + 1))
  else
    minor=0
    major=$((major + 1))
  fi
fi

new_version="$major.$minor.$patch"

yq e -i ".version = \"$new_version\"" "$CHART_FILE"

echo "Version updated: $current_version → $new_version"

pre-commit run --show-diff-on-failure --color=always --verbose --all-files --show-diff-on-failure
