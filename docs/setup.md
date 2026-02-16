# Setup Guide

This guide walks through setting up your Kairos OS cluster with ArgoCD and bootstrap components.

## Prerequisites

- Kairos OS cluster with MetalLB already installed
- kubectl configured and authenticated to your cluster
- Terraform configured to deploy to your cluster
- Git SSH or HTTPS access configured
- Docker or container runtime available

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│        Kairos OS Cluster                    │
│  (MetalLB already installed)                │
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
│  - CRDs                                     │
│  - StorageClasses                           │
│  - Gateway API                              │
│  - Envoy Gateway                            │
│  - Networking policies & MetalLB config     │
└─────────────────────────────────────────────┘
```

## Step 1: Prepare Terraform

Your Terraform code should:

1. **Install ArgoCD to the cluster:**

   ```hcl
   resource "helm_release" "argocd" {
     name       = "argocd"
     repository = "https://argoproj.github.io/argo-helm"
     chart      = "argo-cd"
     namespace  = "argocd"
     create_namespace = true

     values = [file("${path.module}/argocd-values.yaml")]
   }
   ```

2. **Create the ArgoCD Application pointing to this repository:**

   ```hcl
   resource "helm_release" "bootstrap_app" {
     depends_on = [helm_release.argocd]

     name   = "bootstrap"
     chart  = "${path.module}/argocd-bootstrap-app"
     namespace = "argocd"

     set {
       name  = "repository.url"
       value = "https://github.com/fam-melcher/homelab-argocd.git"
     }

     set {
       name  = "repository.targetRevision"
       value = "main"
     }
   }
   ```

## Step 2: Deploy with Terraform

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

## Step 3: Verify ArgoCD Sync

```bash
# Forward ArgoCD port to access web UI (optional)
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Then visit: https://localhost:8080
# Default username: admin
# Get password: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Or, check application status via CLI
kubectl get applications -n argocd
kubectl describe application bootstrap -n argocd
```

## Step 4: Monitor Bootstrap Sync

```bash
# Watch bootstrap components sync
kubectl get applications -n argocd -w

# Check specific components
kubectl get storageclass
kubectl api-resources | grep gateway
kubectl get envoygateway -n envoy-gateway-system
```

## Troubleshooting

### ArgoCD not syncing

```bash
# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check application details
kubectl describe application bootstrap -n argocd
```

### Bootstrap components not appearing

```bash
# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check if CRDs are installed
kubectl get crd | grep gateway
```

### MetalLB issues

```bash
# Verify MetalLB is running
kubectl get pods -n metallb-system

# Check MetalLB configuration
kubectl get configmap -n metallb-system
```

## Next Steps

1. Once bootstrap components are synced, your cluster is ready for applications
2. All applications should reference bootstrap components (e.g., use StorageClasses defined here)
3. See [Architecture](architecture.md) for component details
4. See [Maintenance](maintenance.md) for update procedures

## Version Tracking

All components use pinned versions for reproducibility. See [Maintenance](maintenance.md) for how to update versions safely.
