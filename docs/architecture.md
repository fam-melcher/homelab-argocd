# Architecture & Design

This document explains the architecture and design decisions for this bootstrap repository.

## Overall Design Philosophy

**Reproducibility First:** Every cluster bootstrapped from this repository should be identical. All versions are pinned, all configurations are explicit.

**Infrastructure as Code:** All infrastructure is defined in declarative YAML/Kustomize. No manual kubectl commands in production.

**GitOps via ArgoCD:** The source of truth is Git. All desired state flows from this repository through ArgoCD to the cluster.

**Scope:** Infrastructure layer only - foundational components for Kairos OS cluster readiness. No application deployments.

## Component Architecture

Current bootstrap components installed by ArgoCD in order:

### 1. CRDs (`bootstrap/crds/`)

**Purpose:** Install Custom Resource Definitions required by other bootstrap components.

**Current contents:**

- Kairos NodeOp CRDs - enables declarative node configuration

**Why separate:** CRDs must exist before operators that use them. This folder ensures they're applied first in the bootstrap sequence.

**Versioning:** All CRD manifests pinned to specific versions.

**Kairos NodeOp CRD usage:**

NodeOp resources allow declarative node-level configuration on Kairos OS:

```yaml
apiVersion: kairos.io/v1
kind: NodeOp
metadata:
  name: configure-kube-apiserver
spec:
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  # Configuration that NodeOp controller will apply to matching nodes
```

### 2. K3s Configuration (`bootstrap/k3s/`)

**Purpose:** Configure K3s-specific settings required for cluster operation.

**Current contents:**

- K3s API server node operator configuration
- Sets K3s-specific admission plugins and API server flags

**Why important:** K3s is the distribution used by Kairos OS. This component ensures K3s API server is configured according to bootstrap requirements.

**Example configuration:**

```yaml
apiVersion: kairos.io/v1
kind: NodeOp
metadata:
  name: configure-kube-apiserver
spec:
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  sequence:
    - name: kube-apiserver-config
      # K3s API server configuration applied via systemd/kubelet service
```

### 3. Pod Security (`bootstrap/security/`)

**Purpose:** Define pod security policies and admission controls.

**Current contents:**

- Pod Security admission plugin configuration for control plane nodes
- Uses Kairos NodeOp to deploy pod security policies

**Why important:** Controls which pods can run on the cluster based on security policies.

**Pod Security Levels:**

- `restricted` - Most restrictive, suitable for production
- `baseline` - Minimal restrictions, includes common security best practices
- `privileged` - Allows all capabilities (use sparingly)

**Example:**

```yaml
apiVersion: kairos.io/v1
kind: NodeOp
metadata:
  name: k3s-pod-security
spec:
  # Configures K3s to use pod security admission plugin
  sequence:
    - name: pod-security-setup
      # Deployment of pod security admission configuration
```

## Deployment Architecture

```
┌──────────────────────────────────┐
│  Kairos OS Cluster               │
│  (with K3s pre-installed)        │
└──────────────────────────────────┘
           ↓
┌──────────────────────────────────┐
│  Terraform                       │
│  - Installs ArgoCD via Helm      │
└──────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────┐
│  ArgoCD in argocd namespace                  │
│  - Server                                    │
│  - Application Controller                    │
│  - Repository Server                         │
└──────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────┐
│  ArgoCD syncs this repository (bootstrap/)   │
│  Applies components in order:                │
│  1. CRDs (Kairos NodeOp)                     │
│  2. K3s Configuration                        │
│  3. Pod Security Configuration               │
└──────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────┐
│  Cluster Ready                   │
│  - CRDs registered               │
│  - K3s configured                │
│  - Pod security enforced         │
└──────────────────────────────────┘
```

## Deployment Order

Components are applied in strict order via `bootstrap/kustomization.yaml`:

1. **CRDs first** - Kairos NodeOp CRDs must exist before NodeOp resources
2. **K3s Configuration** - Configures API server and cluster networking
3. **Pod Security** - Applies security policies to nodes

**Why order matters:**

- Kubernetes requires CRDs to exist before resources that reference them
- K3s API server configuration must be set early for pod security policies to work
- Pod security policies then enforced at admission time

## Kustomize Structure

Each component uses Kustomize for composition:

```
bootstrap/
├── kustomization.yaml          # Root Kustomization
├── crds/
│   ├── kustomization.yaml
│   └── nodeop-crd.yaml
├── k3s/
│   ├── kustomization.yaml
│   └── configure-kube-apiserver-nodeop.yaml
└── security/
    ├── kustomization.yaml
    └── k3s-pod-security-nodeop.yaml

argocd/
├── kustomization.yaml          # Root Kustomization
├── root-application.yaml       # Bootstrap Application
└── applications/
    ├── kustomization.yaml
    ├── bootstrap-application.yaml
    └── kairos-operator-application.yaml
```

**Kustomize benefits:**

- Declarative resource composition
- Reusable base configurations
- Consistent labeling across all resources
- Version pinning for all referenced resources

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

The bootstrap process is driven by ArgoCD Applications:

**Root Application** (`argocd/root-application.yaml`):

- Points to `bootstrap/` directory
- Syncs bootstrap components
- Applies with `prune: true` and `selfHeal: true`

**Automatic Sync Policies:**

```yaml
syncPolicy:
  automated:
    prune: true       # Remove resources deleted from Git
    selfHeal: true    # Correct drift from Git state
```

**Key principle:** If it's not in Git, it gets deleted. If cluster state drifts from Git, ArgoCD corrects it.

## Disaster Recovery

Because everything is GitOps:

1. **Cluster lost?** Deploy new Kairos OS + Terraform + ArgoCD sync = identical cluster
2. **Configuration changed manually?** ArgoCD syncs from Git automatically (selfHeal)
3. **Resource deleted accidentally?** ArgoCD reapplies from Git (prune + selfHeal)
4. **Version issues?** Git history shows exact versions deployed and when

## Future Extensibility

To add new bootstrap components:

1. Create folder under `bootstrap/<component>/`
2. Define all resources (YAML manifests or NodeOp declarations)
3. Create `kustomization.yaml` for the component
4. Add to `bootstrap/kustomization.yaml` resources list
5. Document changes in this file
6. Test with ArgoCD sync
7. Commit and push

Example future additions:

- StorageClass definitions
- NetworkPolicy defaults
- Cert-manager for certificate management
- Observability infrastructure (logging, metrics)
- Service mesh foundations

## CI/CD Pipeline

Before any bootstrap component reaches `main`:

1. **Static Analysis** - yamllint for YAML syntax
2. **Schema Validation** - kubeconform for Kubernetes manifest validity
3. **Build Validation** - kustomize build to catch composition errors
4. **Image Pinning** - verification that no `latest` tags are used
5. **Secret Scanning** - ensure no credentials are committed

See `.github/workflows/validate-bootstrap.yml` for implementation.
