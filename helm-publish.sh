#!/bin/bash

set -e

CHART_PATH="./helm"
CHART_FILE="$CHART_PATH/Chart.yaml"

# Function to get current version from Chart.yaml
get_current_version() {
  grep "^version:" "$CHART_FILE" | cut -d' ' -f2
}

# Function to increment version
increment_version() {
  local version=$1
  local type=$2
  
  IFS='.' read -ra PARTS <<< "$version"
  local major=${PARTS[0]}
  local minor=${PARTS[1]}
  local patch=${PARTS[2]}
  
  case $type in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    revision)
      patch=$((patch + 1))
      ;;
  esac
  
  echo "$major.$minor.$patch"
}

# Function to update Chart.yaml version
update_chart_version() {
  local new_version=$1
  sed -i "s/^version:.*/version: $new_version/" "$CHART_FILE"
}

# Parse command line arguments
VERSION=""
BUMP_TYPE=""
NO_BUMP=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    -m|--major)
      BUMP_TYPE="major"
      shift
      ;;
    -n|--minor)
      BUMP_TYPE="minor"
      shift
      ;;
    -r|--revision)
      BUMP_TYPE="revision"
      shift
      ;;
    -x|--no-bump)
      NO_BUMP=true
      shift
      ;;
    *)
      echo "Unknown option $1"
      echo "Usage: $0 [-v VERSION] [-m] [-n] [-r] [-x]"
      echo "  -v, --version    Specify exact version"
      echo "  -m, --major      Bump major version"
      echo "  -n, --minor      Bump minor version"
      echo "  -r, --revision   Bump revision/patch version"
      echo "  -x, --no-bump    Use current version without bumping"
      exit 1
      ;;
  esac
done

# Determine new version
if [ "$NO_BUMP" = true ]; then
  NEW_VERSION=$(get_current_version)
elif [ -n "$VERSION" ]; then
  NEW_VERSION="$VERSION"
elif [ -n "$BUMP_TYPE" ]; then
  CURRENT_VERSION=$(get_current_version)
  NEW_VERSION=$(increment_version "$CURRENT_VERSION" "$BUMP_TYPE")
else
  echo "Error: Must specify either a version (-v), bump type (-m/-n/-r), or --no-bump (-x)"
  exit 1
fi

echo "Current version: $(get_current_version)"
echo "New version: $NEW_VERSION"

# Update Chart.yaml
update_chart_version "$NEW_VERSION"
echo "Updated Chart.yaml with version $NEW_VERSION"

# Get chart name from Chart.yaml
CHART_NAME=$(grep "^name:" "$CHART_FILE" | cut -d' ' -f2)

# Package chart
echo "Packaging chart..."
helm package "$CHART_PATH"

REPO_OWNER=$(gh repo view --json nameWithOwner --jq .nameWithOwner|sed -E 's|(.*)/.*$|\1|'|tr '[:upper:]' '[:lower:]')

# Push to GitHub Container Registry
PACKAGE_FILE="${CHART_NAME}-${NEW_VERSION}.tgz"
REGISTRY_URL="oci://ghcr.io/${REPO_OWNER}"

echo "Pushing chart to $REGISTRY_URL..."
helm push "$PACKAGE_FILE" "$REGISTRY_URL"

echo "Successfully published $CHART_NAME:$NEW_VERSION to GitHub Container Registry"
echo "Install with: helm install my-app $REGISTRY_URL/$CHART_NAME --version $NEW_VERSION"

# Clean up package file
rm "$PACKAGE_FILE"
