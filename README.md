# Kubernetes Minimum AZ Nodes

This application is designed for EKS/Karpenter environments to ensure at least one node remains available in each Availability Zone (AZ). It deploys lightweight idle pods that prevent Karpenter from scaling down nodes to zero, maintaining cluster readiness and reducing cold start times for new workloads.

This is particularly critical for clusters using Network Load Balancers (NLB) with Kubernetes ingress controllers, which are commonly used to connect AWS API Gateway to Kubernetes services. NLBs require healthy targets in each AZ to properly distribute traffic and maintain high availability across zones.

## Building and Pushing the Docker Image

### Prerequisites
- Docker installed and configured
- Access to your container registry (Docker Hub, ECR, etc.)

### Build and Push to Generic Registry

Use the included build script to build and push the Docker image:

```bash
# Build and push with version bump
./build-push.sh -t your-registry/min-nodes -r

# Build and push with specific version
./build-push.sh -t your-registry/min-nodes -v 1.0.0

# Build and push without version bump (use current version)
./build-push.sh -t your-registry/min-nodes -x
```

### Build and Push to AWS ECR

1. **Create ECR repository:**
```bash
aws ecr create-repository --repository-name min-nodes --region us-west-2
```

2. **Get login token:**
```bash
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com
```

3. **Build and push:**
```bash
./build-push.sh -t 123456789012.dkr.ecr.us-west-2.amazonaws.com/min-nodes -r
```

## Publishing the Helm Chart

### Prerequisites
- Helm 3.x installed
- Access to your Helm repository

### Publish to GitHub Container Registry (Default)

The included script publishes to GitHub Container Registry:

```bash
# Publish with version bump
./helm-publish.sh -r

# Publish with specific version
./helm-publish.sh -v 1.0.0

# Publish without version bump
./helm-publish.sh -x
```

### Publish to AWS ECR (OCI Registry)

1. **Create ECR repository for Helm charts:**
```bash
aws ecr create-repository --repository-name helm/min-nodes --region us-west-2
```

2. **Login to ECR:**
```bash
aws ecr get-login-password --region us-west-2 | helm registry login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com
```

3. **Package and push manually:**
```bash
helm package ./helm
helm push min-nodes-*.tgz oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/helm
```

## Installing the Helm Chart

### Basic Installation

```bash
# Install from GitHub Container Registry
helm install min-nodes oci://ghcr.io/mikejansen/min-nodes --version 0.2.0

# Install from AWS ECR
helm install min-nodes oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/helm/min-nodes --version 0.2.0
```

### Installation with Custom Values

1. **Create a values file (values-prod.yaml):**
```yaml
# Update to point to your Docker image
image:
  repository: "123456789012.dkr.ecr.us-west-2.amazonaws.com"
  name: min-nodes
  tag: "1.0.0"
  pullPolicy: IfNotPresent

# Set replica count to match your AZ count
replicaCount: 3  # For 3 AZs

# Adjust resources if needed
resources:
  requests:
    cpu: 5m
    memory: 8Mi
  limits:
    cpu: 10m
    memory: 16Mi

# Custom priority settings
priority:
  className: system-cluster-critical
  value: 2000

# Security context
security:
  runAsUser: 65534
  runAsGroup: 65534
  fsGroup: 65534
```

2. **Install with custom values:**
```bash
helm install min-nodes oci://ghcr.io/mikejansen/min-nodes --version 0.2.0 -f values-prod.yaml
```

3. **Upgrade existing installation:**
```bash
helm upgrade min-nodes oci://ghcr.io/mikejansen/min-nodes --version 0.2.0 -f values-prod.yaml
```

## Configurable Values

The following values can be overridden in your values file or via `--set` flags:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.labelPrefix` | Label prefix for Kubernetes resources | `cr0w.co` |
| `image.repository` | Docker image repository | `""` |
| `image.name` | Docker image name | `idle` |
| `image.tag` | Docker image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `replicaCount` | Number of replicas (**should match AZ count**) | `3` |
| `resources.requests.cpu` | CPU request | `10m` |
| `resources.requests.memory` | Memory request | `16Mi` |
| `resources.limits.cpu` | CPU limit | `10m` |
| `resources.limits.memory` | Memory limit | `16Mi` |
| `priority.className` | Priority class name | `high-priority-idle-app` |
| `priority.value` | Priority value | `1000` |
| `security.runAsUser` | User ID to run container | `65534` |
| `security.runAsGroup` | Group ID to run container | `65534` |
| `security.fsGroup` | Filesystem group ID | `65534` |

### Important Notes

- **replicaCount**: This should match the number of Availability Zones in your cluster to ensure one node per AZ
- **Priority**: The pods use high priority to avoid eviction but should be lower than critical system components
- **Resources**: Minimal resources are used since these are idle placeholder pods