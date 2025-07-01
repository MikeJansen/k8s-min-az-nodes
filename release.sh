#!/usr/bin/env bash

set -e

# Get commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null|grep ^v|head -n1)
if [ -z "$LAST_TAG" ]; then
    COMMITS=$(git log --pretty=format:"%s" --no-merges)
else
    COMMITS=$(git log ${LAST_TAG}..HEAD --pretty=format:"%s" --no-merges)
fi

echo "Commits since last release:"
echo "$COMMITS"

NUM_FEAT=0
NUM_FIX=0
NUM_CHORE=0
NUM_BREAKING=0

process_commit() {
    local type="$1"
    local scope="$2"
    local breaking="$3"
    local issue="$4"
    local message="$5"

    echo "Processing commit: $type($scope)$breaking: $issue - $message"

    case "$type" in
        feat)
            NUM_FEAT=$((NUM_FEAT + 1))
            ;;
        fix)
            NUM_FIX=$((NUM_FIX + 1))
            ;;
        chore)
            NUM_CHORE=$((NUM_CHORE + 1))
            ;;
    esac

    if [ -n "$breaking" ]; then
        NUM_BREAKING=$((NUM_BREAKING + 1))
    fi
}

while read -r commit; do
    TO_EVAL="$(echo "$commit" | sed -En 's/^(feat|fix|chore)(\(([^)]+)\))?(!)?:[[:space:]]*(#([[:alnum:]-]+)[[:space:]]*)?(.+)$/process_commit "\1" "\3" "\4" "\6" "\7"/p')"
    eval "$TO_EVAL"
done < <(echo "$COMMITS")

echo "Release Summary:"
echo "Features: $NUM_FEAT"
echo "Fixes: $NUM_FIX"
echo "Chores: $NUM_CHORE"
if [ $NUM_BREAKING -gt 0 ]; then
    echo "Breaking Changes: $NUM_BREAKING"
else
    echo "No Breaking Changes"
fi

if [ $NUM_BREAKING -gt 0 ]; then
    echo "Major"
    BUMP="major"
elif [ $NUM_FEAT -gt 0 ]; then
    echo "Minor"
    BUMP="minor"
elif [ $NUM_FIX -gt 0 ]; then
    echo "Patch"
    BUMP="revision"
else
    echo "No Changes"
    BUMP=""
fi

if [ -z "$BUMP" ]; then
    echo "No changes to release."
    exit 0
fi

REPO_OWNER=$(gh repo view --json nameWithOwner --jq .nameWithOwner|sed -E 's|(.*)/.*$|\1|'|tr '[:upper:]' '[:lower:]')
./build-push.sh --tag "ghcr.io/${REPO_OWNER}/idle" --${BUMP} --update-chart
./helm-publish.sh --${BUMP}
