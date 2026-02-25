# Setup Guide

This guide walks through setting up your Kairos OS cluster with ArgoCD and bootstrap components.

## Prerequisites

- Kairos OS cluster installed and running
- kubectl configured and authenticated to your cluster
- Terraform configured to deploy to your cluster
- Git SSH or HTTPS access configured
- Access to this repository (fork or clone)

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│        Kairos OS Cluster                    │
│  (K3s pre-installed)                        │
└─────────────────────────────────────────────┘
                    ↓
        Terraform Deploy ArgoCD
                    ↓
┌─────────────────────────────────────────────┐
│        ArgoCD Namespace (argocd)            │
│  - Server                                   │
│  - Controller                               │
│  - Application Controller                   │
└─────────────────────────────────────────────┘
                    ↓
        ArgoCD Syncs from GitHub
                    ↓
┌─────────────────────────────────────────────┐
│   Bootstrap Components (from this repo)     │
│  - CRDs (Kairos NodeOp)                     │
│  - K3s Configuration                        │
│  - Pod Security Configuration               │
└─────────────────────────────────────────────┘
```

## Step 1: Prepare Terraform

Your Terraform code should install ArgoCD to the cluster using Helm:

```hcl
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "X.Y.Z"  # Pin to specific version
}
```

## Step 2: Configure ArgoCD to Sync Bootstrap Repository

Create an ArgoCD Application that points to this repository's bootstrap components:

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
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply this to your cluster:

```bash
kubectl apply -f application-bootstrap.yaml
```

## Step 3: Deploy with Terraform

```bash
# From your Terraform directory
cd terraform/

# Plan the deployment
terraform plan

# Apply changes (will take 5-10 minutes for ArgoCD to be ready)
terraform apply

# Verify ArgoCD is running
kubectl get pods -n argocd
```

## Step 4: Verify ArgoCD Sync

```bash
# Check application status
kubectl get applications -n argocd
kubectl describe application bootstrap -n argocd

# Watch bootstrap components sync
kubectl get applications -n argocd -w
```

## Step 5: Verify Bootstrap Components

```bash
# Verify CRDs are installed
kubectl get crd | grep nodeop

# Verify Gateway API CRDs are installed
kubectl get crd | grep gateway.networking.k8s.io

# Verify Envoy Gateway is running
kubectl get pods -n envoy-gateway-system

# Verify the GatewayClass and default Gateway exist
kubectl get gatewayclass
kubectl get gateway -A

# Check that bootstrap components are deployed
kubectl get nodes -o wide  # Should show K3s configuration applied

# Verify pod security is enforced
kubectl get pods -A  # Should show security context applied
```

Note: the default Envoy Gateway Service is typically `LoadBalancer`. If you have disabled K3s `servicelb` (as this repo does) you will need an alternative load balancer implementation (for example MetalLB) for an external IP.

## Troubleshooting

### ArgoCD not syncing

```bash
# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# Check application details
kubectl describe application bootstrap -n argocd
```

### Bootstrap components not appearing

```bash
# Check ArgoCD application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Verify CRDs are installed
kubectl get crd nodeop.kairos.io
```

### K3s configuration not applied

```bash
# Check K3s node operator logs
kubectl logs -n kube-system -l app=k3s-node-operator -f

# Verify node configuration
kubectl describe node <node-name>
```

## Next Steps

1. Once bootstrap components are synced, your cluster is ready for applications
2. All applications should reference bootstrap components as appropriate
3. See [Architecture](architecture.md) for detailed component information
4. See [Maintenance](maintenance.md) for update and upgrade procedures

All components use pinned versions for reproducibility. See [Maintenance](maintenance.md) for how to update versions safely.
