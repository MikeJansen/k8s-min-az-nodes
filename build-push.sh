#!/bin/bash

set -e

VERSION_FILE=".image-version"

# Function to get current version from file
get_current_version() {
  if [ -f "$VERSION_FILE" ]; then
    cat "$VERSION_FILE"
  else
    echo "0.1.0"
  fi
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

# Function to save version to file
save_version() {
  local version=$1
  echo "$version" > "$VERSION_FILE"
}

# Parse command line arguments
TAG=""
VERSION=""
BUMP_TYPE=""
NO_BUMP=false
UPDATE_CHART=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--tag)
      TAG="$2"
      shift 2
      ;;
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
    -h|--update-chart)
      UPDATE_CHART=true
      shift
      ;;
    *)
      echo "Unknown option $1"
      echo "Usage: $0 -t <tag> [-v VERSION] [-m] [-n] [-r] [-x] [-h]"
      echo "  -t, --tag          Base tag for the image (required)"
      echo "  -v, --version      Specify exact version"
      echo "  -m, --major        Bump major version"
      echo "  -n, --minor        Bump minor version"
      echo "  -r, --revision     Bump revision/patch version"
      echo "  -x, --no-bump      Use current version without bumping"
      echo "  -h, --update-chart Update helm chart appVersion to match docker version"
      exit 1
      ;;
  esac
done

# Check if tag is provided
if [ -z "$TAG" ]; then
  echo "Error: Tag is required"
  echo "Usage: $0 -t <tag> [-v VERSION] [-m] [-n] [-r]"
  exit 1
fi

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

# Save new version
save_version "$NEW_VERSION"

# Update helm chart appVersion if requested
if [ "$UPDATE_CHART" = true ]; then
  CHART_FILE="./helm/Chart.yaml"
  if [ -f "$CHART_FILE" ]; then
    echo "Updating helm chart appVersion to $NEW_VERSION"
    sed -i "s/^appVersion:.*/appVersion: \"$NEW_VERSION\"/" "$CHART_FILE"
  else
    echo "Warning: helm/Chart.yaml not found, skipping chart update"
  fi
fi

# Create tag names
VERSION_TAG="${TAG}:${NEW_VERSION}"
LATEST_TAG="${TAG}:latest"

echo "Building Docker image..."
docker build -t "$VERSION_TAG" -t "$LATEST_TAG" .

echo "Pushing Docker images..."
docker push "$VERSION_TAG"
docker push "$LATEST_TAG"

echo "Build and push completed successfully!"
echo "Published: $VERSION_TAG and $LATEST_TAG"