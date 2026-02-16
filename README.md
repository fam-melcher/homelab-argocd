# Homelab ArgoCD Bootstrap Repository

A reproducible Kubernetes cluster bootstrap template using ArgoCD. This repository serves as the source of truth for cluster initialization, installing foundational components and CRDs needed to run applications on Kairos OS.

## Overview

This repository is deployed by Terraform to Kairos OS clusters. It installs and configures ArgoCD, then ArgoCD synchronizes all bootstrap components from this repository.

**Use Case:** Reproducible cluster setup - spin up identical clusters every time.

## Architecture

```
Terraform
    ↓
Deploy ArgoCD to cluster
    ↓
ArgoCD syncs from this repository
    ↓
Bootstrap components installed:
  - CRDs
  - Storage Classes
  - Gateway API
  - Envoy Gateway
  - Networking (network policies, etc.)
```

## Repository Structure

```
homelab-argocd/
├── argocd/                          # ArgoCD installation & configuration
├── bootstrap/
│   ├── crds/                        # Custom Resource Definitions
│   ├── storage/                     # StorageClasses and PersistentVolume setup
│   ├── gateway-api/                 # Kubernetes Gateway API installation
│   ├── envoy-gateway/               # Envoy Gateway operator & configuration
│   └── networking/                  # NetworkPolicies, CNI configs
├── docs/                            # Project documentation
└── README.md                        # This file
```

## Prerequisites

- Kairos OS cluster with MetalLB installed
- Terraform setup to deploy ArgoCD
- kubectl access to the cluster
- Git configured for SSH or HTTPS

## Quick Start

### 1. Bootstrap a New Cluster

```bash
# Terraform will:
# 1. Install ArgoCD to the cluster
# 2. Configure ArgoCD to sync from this repository
# 3. Wait for all bootstrap components to sync

terraform apply
```

### 2. Monitor Sync Status

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Watch sync progress
kubectl get applications -n argocd -w
```

### 3. Verify Bootstrap Components

```bash
# Check StorageClasses
kubectl get storageclass

# Check Gateway API resources
kubectl api-resources | grep gateway

# Check Envoy Gateway
kubectl get envoygateway -n envoy-gateway-system
```

## Documentation

See [docs/](docs/) for:

- [Setup Guide](docs/setup.md) - Detailed setup and deployment process
- [Architecture](docs/architecture.md) - Component relationships and design decisions
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Maintenance](docs/maintenance.md) - Updates and version management

## Components

### CRDs (`bootstrap/crds/`)

Custom Resource Definitions required by other bootstrap components.

### Storage (`bootstrap/storage/`)

StorageClasses for persistent storage. Configure based on your infrastructure.

### Gateway API (`bootstrap/gateway-api/`)

Kubernetes Gateway API CRDs and controllers. Foundation for Envoy Gateway.

### Envoy Gateway (`bootstrap/envoy-gateway/`)

API gateway and ingress controller using Envoy.

### Networking (`bootstrap/networking/`)

MetalLB configuration, network policies, and networking setup.

## Development Workflow

All changes follow [conventional commits](https://www.conventionalcommits.org/):

```bash
# Create a feature branch
git checkout main
git pull origin main
git checkout -b feat/add-networkpolicy-templates

# Make changes, test in your cluster

# Commit with conventional commits
git commit -m "feat: add default network policies for pod-to-pod communication" ./bootstrap/networking/

# Push to branch (never push to main!)
git push origin feat/add-networkpolicy-templates

# Create Pull Request for review
```

### Branch Naming

Follow the pattern: `<type>/<description>`

**Types** (from Conventional Commits):

- `feat` - New feature
- `fix` - Bug fix
- `chore` - Maintenance, updates
- `docs` - Documentation
- `refactor` - Code restructuring
- `test` - Tests
- `ci` - CI/CD changes

**Examples:**

- `feat/envoy-gateway-setup`
- `fix/metallb-config-bug`
- `chore/update-gateway-api-version`
- `docs/add-troubleshooting-guide`

## Contributing

1. Read the [GitHub Copilot Instructions](.github/copilot-instructions.md) for development guidelines
2. Never commit directly to `main`
3. Always pull latest before creating a branch
4. Test changes in a non-production environment first
5. Use descriptive commit messages following conventional commits

## Support

Refer to:

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [Kairos OS](https://kairos.io/)

## License

GNU General Public License v3.0 - This project is open source and available under the GPLv3 License. See [LICENSE](LICENSE) file for details.

---

**Last Updated:** February 2026
**Maintained by:** Michael Melcher
