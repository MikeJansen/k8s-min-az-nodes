set -e
unset GITHUB_TOKEN
gh auth login --web --git-protocol https --hostname github.com --scopes write:packages
GH_USER=$(gh auth status --active|grep 'Logged'|sed -E 's/.* account (.+) .*/\1/'|tr '[:upper:]' '[:lower:]')
gh auth token | docker login ghcr.io -u "$GH_USER" --password-stdin
gh auth token | helm registry login ghcr.io -u "$GH_USER" --password-stdin
