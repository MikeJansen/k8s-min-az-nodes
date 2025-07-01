# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Kubernetes application for EKS/Karpenter environments that ensures at least one node remains available in each Availability Zone (AZ). It deploys lightweight idle pods to prevent Karpenter from scaling nodes to zero, maintaining cluster readiness for workloads requiring Network Load Balancer (NLB) high availability.

## Key Commands

### Building and Testing
```bash
# Build Docker image locally
docker build -t idle:latest .

# Local integration test with Minikube (creates 3-node cluster, tests deployment)
./local-test.sh

# Build and push Docker image with version bump
./build-push.sh -t your-registry/min-nodes -r

# Build and push to AWS ECR
./build-push.sh -t 123456789012.dkr.ecr.us-west-2.amazonaws.com/min-nodes -r
```

### Helm Chart Management
```bash
# Publish Helm chart to GitHub Container Registry with version bump
./helm-publish.sh -r

# Install from GitHub Container Registry
helm install min-nodes oci://ghcr.io/mikejansen/min-nodes --version 0.2.0

# Install with custom values
helm install min-nodes oci://ghcr.io/mikejansen/min-nodes --version 0.2.0 -f values-prod.yaml

# Local Helm test installation
helm install min-nodes ./helm --set image.pullPolicy=IfNotPresent --set replicaCount=3
```

### Development Workflow
```bash
# Manual release process (handles versioning, Docker build/push, Helm publish)
./release.sh

# Check current version
cat .image-version
```

## Architecture Overview

**Single-file Go application** (`main.go`):
- HTTP server with `/health` endpoint on port 8080
- Graceful shutdown handling
- Minimal resource footprint (10m CPU, 16Mi memory)

**Kubernetes deployment strategy**:
- **Topology spread constraints**: Distributes pods across availability zones
- **Pod anti-affinity**: Prevents multiple pods per zone
- **Priority class**: High priority (1000) to resist eviction
- **Pod disruption budget**: Maintains availability during updates
- **Security context**: Non-root execution, read-only filesystem

**Container design**:
- Multi-stage build with `golang:1.23-alpine` builder
- Final image uses `scratch` base for minimal attack surface
- Static binary with CGO disabled

## Critical Configuration

**Helm values** (`helm/values.yaml`):
- `replicaCount`: Must match number of AZs (default: 3)
- `priority.value`: 1000 (high priority, but below system-critical)
- `security.runAsUser`: 65534 (nobody user)
- `resources`: Minimal CPU/memory allocation

**Version management**:
- `.image-version`: Tracks current Docker image version
- Semantic versioning with automated CI/CD bumping
- Conventional commits drive version increments

## Release Process

**Automated via GitHub Actions**:
- `build.yml`: Runs on PRs, tests with Minikube
- `release.yml`: Runs on main branch, handles versioning/publishing

**Manual release**:
1. Use `./release.sh` for full release cycle
2. Updates `.image-version` file
3. Builds/pushes Docker image to GitHub Container Registry
4. Packages/publishes Helm chart

## AWS ECR Integration

**Docker images**:
```bash
aws ecr create-repository --repository-name min-nodes --region us-west-2
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-west-2.amazonaws.com
```

**Helm charts**:
```bash
aws ecr create-repository --repository-name helm/min-nodes --region us-west-2
helm registry login --username AWS --password-stdin <account>.dkr.ecr.us-west-2.amazonaws.com
```

## Security Considerations

- Container runs as non-root user (65534)
- Read-only root filesystem
- All capabilities dropped
- Seccomp profile: RuntimeDefault
- Scratch-based image for minimal attack surface