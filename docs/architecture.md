# Architecture & Design

This document explains the architecture and design decisions for this bootstrap repository.

## Overall Design Philosophy

**Reproducibility First:** Every cluster bootstrapped from this repository should be identical. All versions are pinned, all configurations are explicit.

**Infrastructure as Code:** All infrastructure is defined in declarative YAML/Kustomize. No manual kubectl commands in production.

**GitOps via ArgoCD:** The source of truth is Git. All desired state flows from this repository through ArgoCD to the cluster.

## Component Architecture

### 1. CRDs (`bootstrap/crds/`)

**Purpose:** Install Custom Resource Definitions required by other components.

**Examples:**

- Gateway API CRDs (HTTPRoute, Gateway, GatewayClass, etc.)
- Envoy Gateway CRDs
- Cert-manager CRDs (if used)

**Why separate:** CRDs must exist before operators that use them. This folder ensures they're applied first.

**Versioning:** Pin all CRD manifests to specific versions.

### 2. Storage (`bootstrap/storage/`)

**Purpose:** Define available storage options for the cluster.

**What's included:**

- Default StorageClass definition
- StorageClasses for different performance tiers (fast, standard, archive)
- PersistentVolume configurations if using local storage

**Why important:** Applications need to know what storage is available. Defines the contract.

**Configuration:** Should be customized based on your infrastructure:

```yaml
# Example: Different storage tiers
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: your-storage-provider
parameters:
  iops: "1000"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: your-storage-provider
```

### 3. Gateway API (`bootstrap/gateway-api/`)

**Purpose:** Install Kubernetes Gateway API resources.

**What's included:**

- Gateway API CRDs
- GatewayClass definitions
- Standard Gateway configurations

**Why:** Gateway API is the modern standard for Kubernetes networking. It replaces Ingress in many scenarios.

**Relationship to Envoy Gateway:** Gateway API is the API layer, Envoy Gateway is the implementation.

### 4. Envoy Gateway (`bootstrap/envoy-gateway/`)

**Purpose:** Deploy Envoy Gateway operator and configure it.

**What's included:**

- Envoy Gateway controller pod
- EnvoyGateway CRD and default configuration
- RBAC and networking setup

**Features:**

- Multiple transport protocols (HTTP, HTTPS, TCP, UDP)
- Advanced load balancing
- Service mesh integration ready

**Configuration:** The EnvoyGateway resource defines cluster-wide defaults:

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyGateway
metadata:
  name: default
spec:
  provider:
    type: Kubernetes
  logging:
    level: info
```

### 5. Networking (`bootstrap/networking/`)

**Purpose:** Configure cluster networking and security.

**What's included:**

- MetalLB configuration (L2 advertisement, IP pools)
- Default NetworkPolicies (deny-all, then allow specific traffic)
- CoreDNS configuration (if needed)
- Network policies for bootstrap components themselves

**MetalLB Config Example:**

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: config
  namespace: metallb-system
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.100-192.168.1.120
```

**NetworkPolicies:**

- Default: Deny all traffic (explicit is better than implicit)
- Then: Allow specific traffic (pod-to-pod, pod-to-service, etc.)
- Reduces attack surface significantly

## Deployment Flow

```
1. CRDs installed first
   ↓
2. StorageClasses available
   ↓
3. Gateway API installed
   ↓
4. Envoy Gateway deployed (uses Gateway API CRDs)
   ↓
5. Networking configured (uses Envoy Gateway for traffic)
```

## Why This Order Matters

1. **CRDs first:** Operators need CRDs to exist or they crash
2. **Storage second:** No data persistence until storage classes exist
3. **Gateway API third:** Envoy Gateway depends on it
4. **Envoy Gateway fourth:** Needs CRDs from step 1
5. **Networking last:** Can now route traffic to all components

## Kustomize Structure

Each component uses Kustomize for flexibility:

```
bootstrap/envoy-gateway/
├── kustomization.yaml        # Base configuration
├── base/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── rbac.yaml
└── overlays/
    ├── production/
    │   ├── kustomization.yaml
    │   └── patches.yaml
    └── staging/
        ├── kustomization.yaml
        └── patches.yaml
```

This allows:

- Base configuration that works for most cases
- Environment-specific customization without duplicating files

## Version Pinning Strategy

**All external dependencies are pinned to specific versions:**

```yaml
# Bad (not reproducible):
image: envoyproxy/envoy-gateway:latest

# Good (reproducible):
image: envoyproxy/envoy-gateway:v1.2.3
```

**Versioning approach:**

1. Pin all container images to specific versions
2. Pin all Helm charts to specific versions (if using)
3. Document why each version is chosen
4. Test thoroughly before upgrading

## ArgoCD Integration

ArgoCD Application manifests (not in this repo, but important to understand):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bootstrap
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/fam-melcher/homelab-argocd.git
    targetRevision: main
    path: bootstrap
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true    # Remove resources not in Git
      selfHeal: true # Resync if cluster drifts from Git
```

**Key points:**

- `targetRevision: main` - Always syncs from main branch
- `automated.prune: true` - Removes resources deleted from Git
- `automated.selfHeal: true` - Corrects any manual cluster changes

## Disaster Recovery

Because everything is GitOps:

1. **Cluster lost?** Deploy new Kairos OS + Terraform = identical cluster
2. **Changes lost?** ArgoCD syncs from Git automatically
3. **Version issues?** Git history shows what was deployed and when

## Future Extensibility

To add new bootstrap components:

1. Create folder under `bootstrap/`
2. Define all resources (CRDs, operators, configs)
3. Pin all versions
4. Add to ArgoCD Application path
5. Document in this file
6. Test in staging first

Example future additions:

- Cert-manager for certificates
- External Secrets Operator for secrets management
- Observability stack (Prometheus, Grafana, Loki)
- Service mesh (Istio, Linkerd)
