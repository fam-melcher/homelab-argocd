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

### 2. K3s Configuration (`ops/kairos/k3s/`)

**Purpose:** Configure K3s-specific settings and manage Kairos OS upgrades.
These resources are **operational** — they are not continuously reconciled by
the bootstrap Application. They are applied on-demand via the `kairos-ops`
ArgoCD Application (manual-sync). Upgrades are applied on-demand via the
`kairos-upgrades` ArgoCD Application (manual-sync).

**Current contents:**

- `configure-kube-apiserver-nodeop.yaml` — K3s API server node operator
  configuration. Sets K3s-specific admission plugins and API server flags.
- `k3s-pod-security-nodeop.yaml` — Pod Security Admission configuration for
  control-plane nodes (NodeOp).
- `upgrades/` — Upgrade entrypoint managed by `kairos-upgrades`.
  - `upgrades/active/` — The single active immutable NodeOpUpgrade manifest.
    Only one upgrade should reside here at a time.
  - `upgrades/archive/` — Completed upgrade manifests preserved for audit/rollback
    reference. Not referenced by the kustomization and not applied by ArgoCD.

**Why separate from bootstrap?**

NodeOp and NodeOpUpgrade resources are one-shot operations that cordon, drain,
and reboot nodes. Placing them in a continuously-reconciled Application
(prune + selfHeal) risks unintended re-runs on every sync. The `kairos-ops`
and `kairos-upgrades` Applications are manual-sync only, giving operators explicit
control over when disruptive actions run.

**K3s API Server Configuration (NodeOp):**

```yaml
apiVersion: operator.kairos.io/v1alpha1
kind: NodeOp
metadata:
  name: configure-kube-apiserver
spec:
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  # Configuration that NodeOp controller will apply to matching nodes
```

**OS Upgrade Configuration (immutable NodeOpUpgrade):**

```yaml
apiVersion: operator.kairos.io/v1alpha1
kind: NodeOpUpgrade
metadata:
  name: kairos-upgrade-YYYY-MM-DD  # dated, immutable name
spec:
  image: quay.io/kairos/ubuntu:24.04-standard-amd64-generic-v3.7.2-k3s-v1.33.7-k3s3
  nodeSelector:
    matchLabels:
      kubernetes.io/arch: amd64
  concurrency: 1
  stopOnFailure: true
```

Each upgrade is a new manifest with a date-based name. The previous manifest is
moved to `upgrades/archive/` and a new manifest is placed in `upgrades/active/`.
This ensures each upgrade run corresponds to a distinct commit in git history.

**On a new cluster:** The `kairos-ops` and `kairos-upgrades` Applications may be
out-of-sync on first bootstrap. Trigger manual syncs as needed, and avoid running
NodeOps and upgrades concurrently.

### 3. Pod Security (operational NodeOp)

**Purpose:** Define pod security policies and admission controls.

Pod Security Admission configuration is deployed to control-plane nodes via a
Kairos `NodeOp` under `ops/kairos/k3s/` and applied on-demand via `kairos-ops`.

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
│  ArgoCD syncs this repository                │
│                                              │
│  bootstrap/ (automated, prune+selfHeal):     │
│  1. CRDs (Kairos NodeOp)                     │
│  2. Security bootstrap resources             │
│                                              │
│  ops/kairos/k3s/ (MANUAL SYNC ONLY):         │
│  3. K3s NodeOps (API server, pod security)   │
│                                              │
│  ops/kairos/k3s/upgrades/ (MANUAL SYNC ONLY):│
│  4. Active Kairos OS/K3s NodeOpUpgrade       │
└──────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────┐
│  Cluster Ready                   │
│  - CRDs registered               │
│  - K3s configured (on demand)    │
│  - Pod security enforced         │
└──────────────────────────────────┘
```

## Deployment Order

Bootstrap components are applied in strict order via `bootstrap/kustomization.yaml`:

1. **CRDs first** - Kairos NodeOp CRDs must exist before NodeOp resources
2. **Pod Security** - Applies security policies to nodes

Operational resources (`ops/kairos/k3s/`) are applied separately via the
`kairos-ops` ArgoCD Application (manual-sync only):

1. **K3s API server NodeOp** - Configures API server and cluster networking
2. **Active NodeOpUpgrade** - Upgrades Kairos OS and K3s to the pinned version

Upgrades are applied via the `kairos-upgrades` ArgoCD Application (manual-sync only).

**Why order matters:**

- Kubernetes requires CRDs to exist before resources that reference them
- K3s API server configuration must be set before pod security policies apply
- Pod security policies are then enforced at admission time
- Operational resources are applied explicitly to avoid unintended re-runs

## Kustomize Structure

Each component uses Kustomize for composition:

```
bootstrap/
├── kustomization.yaml          # Root Kustomization
├── crds/
│   ├── kustomization.yaml
│   └── nodeop-crd.yaml
└── security/
    ├── kustomization.yaml
  # (security bootstrap resources)

ops/
└── kairos/
    └── k3s/
        ├── kustomization.yaml
        ├── configure-kube-apiserver-nodeop.yaml
    ├── k3s-pod-security-nodeop.yaml
        └── upgrades/
      ├── kustomization.yaml
            ├── active/
            │   ├── kustomization.yaml
            │   └── kairos-upgrade-YYYY-MM-DD.yaml   # single active upgrade
            └── archive/
                └── README.md                        # completed upgrades (not applied)

argocd/
├── kustomization.yaml          # Root Kustomization
├── root-application.yaml       # App-of-Apps root
└── applications/
    ├── kustomization.yaml
    ├── bootstrap-application.yaml
    ├── kairos-operator-application.yaml
  ├── kairos-ops-application.yaml
  └── kairos-upgrades-application.yaml
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

- Points to `argocd/applications/` directory (app-of-apps pattern)
- Syncs with `prune: true` and `selfHeal: true`

**Bootstrap Application** (`argocd/applications/bootstrap-application.yaml`):

- Points to `bootstrap/` directory
- Automated sync with `prune: true` and `selfHeal: true`
- Applies CRDs and pod security configuration

**Kairos Ops Application** (`argocd/applications/kairos-ops-application.yaml`):

- Points to `ops/kairos/k3s/` directory
- **Manual-sync only** — no `automated` policy, no prune, no selfHeal
- Applies NodeOp resources on-demand

**Kairos Upgrades Application** (`argocd/applications/kairos-upgrades-application.yaml`):

- Points to `ops/kairos/k3s/upgrades/` directory
- **Manual-sync only** — no `automated` policy, no prune, no selfHeal
- Applies the active NodeOpUpgrade on-demand

**Automatic Sync Policies (bootstrap):**

```yaml
syncPolicy:
  automated:
    prune: true       # Remove resources deleted from Git
    selfHeal: true    # Correct drift from Git state
```

**Manual Sync Policy (kairos-ops):**

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
  # No 'automated' block = manual sync only
```

**Key principle:** Infrastructure foundations (CRDs, pod security) are always
reconciled automatically. Operational resources that cordon/drain/reboot nodes
are applied explicitly, giving operators full control over when disruptions occur.

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
