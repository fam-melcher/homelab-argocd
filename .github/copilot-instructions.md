# GitHub Copilot Instructions

These instructions guide development workflow for the homelab-argocd bootstrap repository. They will evolve as the project matures and needs are better understood.

## Project Context

**Purpose:** Reproducible Kubernetes cluster bootstrap template using ArgoCD on Kairos OS.

**Scope:** Infrastructure-layer only - CRDs, storage, networking, and API gateways. No application deployments yet.

**Deployment:** Terraform installs ArgoCD → ArgoCD syncs this repository → Bootstrap components deployed.

**Key Principle:** Everything is GitOps. Git is the single source of truth.

---

## Development Workflow

### Before Starting Any Work

1. **Switch to main branch:**

   ```bash
   git switch main
   ```

2. **Pull latest changes:**

   ```bash
   git pull origin main
   ```

3. **Create a new branch:**
   ```bash
   git checkout -b <type>/<description>
   ```

### Branch Naming Convention

Format: `<type>/<description>`

**Types (Conventional Commits):**

- `feat` - New feature or component
- `fix` - Bug fix
- `chore` - Maintenance, version updates, refactoring
- `docs` - Documentation only
- `refactor` - Code restructuring without changing behavior
- `test` - Tests or test-related changes
- `ci` - CI/CD changes

**Description Rules:**

- Use lowercase
- Use consistent separators: either hyphens OR underscores (not mixed)
- Exception: if component name contains underscores naturally (e.g., `envoy_gateway`), that's allowed
- Be descriptive but concise (3-5 words typical)
- No trailing slashes or dots

**Examples (using hyphens):**

```bash
git switch -c feat/add-cert-manager-bootstrap
git switch -c fix/metallb-ip-pool-config
git switch -c chore/upgrade-envoy-gateway-v1.5
git switch -c docs/add-deployment-runbook
git switch -c refactor/simplify-networkpolicy-structure
```

**Examples (using underscores):**

```bash
git switch -c feat/add_cert_manager_bootstrap
git switch -c fix/metallb_ip_pool_config
git switch -c chore/upgrade_envoy_gateway_v1_5
```

**Examples (with component underscores):**

```bash
git switch -c feat/install-envoy_gateway
git switch -c chore/update-metallb_config
```

**Anti-examples (DON'T DO):**

```bash
# Bad - too vague
git switch -c feat/update

# Bad - mixing hyphens and underscores without reason
git switch -c feat/add-cert_manager_bootstrap
git switch -c chore/update_nginx-to_xyz

# Bad - has trailing slash
git switch -c feat/add-cert-manager/

# Bad - mixing cases
git switch -c Feat/Add-Cert-Manager
```

---

## Commits

### Commit Message Format

**Single-line commits (if no detailed explanation needed):**

```bash
git commit -m "feat: add cert-manager bootstrap component" ./bootstrap/cert-manager/

# Or for multiple files with same message:
git commit -m "docs: update maintenance guide" ./docs/maintenance.md ./README.md
```

**Multi-line commits (for complex changes):**

```bash
git commit -m "feat: add cert-manager bootstrap component

- Install cert-manager operator
- Configure ClusterIssuer for Let's Encrypt
- Add documentation for certificate management
- Tested on staging cluster successfully

Relates to: #42" ./bootstrap/cert-manager/
```

### Conventional Commits Standard

Format: `<type>: <subject>`

**Rules:**

- Use imperative mood ("add" not "adds" or "added")
- Don't capitalize first letter after colon
- No period at the end of subject line
- Max 50 characters for subject line
- Body separated from subject by blank line
- Wrap body at 72 characters
- Explain WHAT and WHY, not HOW

**Commit Types:**

- `feat:` New feature or component
- `fix:` Bug fix
- `chore:` Maintenance (version updates, refactoring)
- `docs:` Documentation changes only
- `refactor:` Code restructuring
- `test:` Test additions or changes
- `ci:` CI/CD configuration

**Good examples:**

```
feat: add cert-manager to bootstrap components

fix: correct metallb ip pool configuration syntax

chore: upgrade envoy-gateway from v1.2.3 to v1.5.0

docs: add troubleshooting guide for networking issues

refactor: consolidate network policies into single file

test: add validation for kustomize manifests
```

**Bad examples:**

```
Updates                           # Too vague
Added cert-manager                # Wrong mood (added vs add)
fix: Fix bug in config            # Repeats "fix"
FEAT: Add something               # Wrong capitalization
chore: Update version.            # Period at end
```

### Committing Strategy

**Option 1: Single file in commit**

```bash
git commit -m "feat: add postgres storageclass" ./bootstrap/storage/postgres-sc.yaml
```

**Option 2: Multiple files with same message**

```bash
git commit -m "docs: update setup guide with troubleshooting section" ./docs/setup.md ./docs/troubleshooting.md
```

**Option 3: Separate commits for different changes**

```bash
# First commit
git commit -m "feat: add envoy gateway deployment" ./bootstrap/envoy-gateway/deployment.yaml

# Second commit (separate message)
git commit -m "feat: add envoy gateway rbac" ./bootstrap/envoy-gateway/rbac.yaml
```

**⚠️ NEVER commit to main directly. Always use branches.**

---

## Git Commit Examples

### Example 1: Adding a new bootstrap component

```bash
# 1. Create branch
git switch main && git pull
git switch -c feat/add-external-secrets-operator

# 2. Create files
mkdir -p bootstrap/external-secrets
# ... create deployment.yaml, rbac.yaml, etc.

# 3. Commit with multi-line message for complex changes
git commit -m "feat: add external-secrets-operator bootstrap

- Install external-secrets-operator helm chart v0.9.0
- Configure SecretStore and ClusterSecretStore templates
- Add RBAC for service accounts
- Documentation in docs/external-secrets.md
- Tested on staging cluster - no issues

This component enables centralized secret management
across the cluster." ./bootstrap/external-secrets/

# 4. Push to remote
git push origin feat/add-external-secrets-operator

# 5. Create PR, get review, merge to main
```

### Example 2: Fixing a bug

```bash
# 1. Create branch
git switch main && git pull
git switch -c fix/metallb-ipaddresspool-syntax

# 2. Fix the issue
# ... edit bootstrap/networking/metallb-config.yaml

# 3. Commit with explanation of issue
git commit -m "fix: correct metallb IPAddressPool naming convention

Previous config used invalid 'addressPools' field.
Kubernetes Gateway API requires 'address-pools' in ConfigMap.

Error was: 'addressPools' is deprecated, use ConfigMap 'config' key instead" ./bootstrap/networking/metallb-config.yaml

# 4. Push and create PR
git push origin fix/metallb-ipaddresspool-syntax
```

### Example 3: Updating component versions

```bash
# 1. Create branch
git switch main && git pull
git switch -c chore/upgrade-argocd-v2.10-to-v2.11

# 2. Update manifests
# ... update all image references from v2.10 to v2.11
# ... update CRDs if needed

# 3. Commit with version details
git commit -m "chore: upgrade argocd from v2.10.0 to v2.11.0

Release: https://github.com/argoproj/argo-cd/releases/tag/v2.11.0

Changes:
- Updated server deployment image
- Updated controller deployment image
- Updated repo-server deployment image
- No CRD changes required
- No breaking changes reported

Tested on staging cluster - all components sync correctly" ./argocd/

# 4. Push and create PR
git push origin chore/upgrade-argocd-v2.10-to-v2.11
```

### Example 4: Multiple commits for different aspects

```bash
# For large features, separate logical changes into different commits

git switch main && git pull
git switch -c feat/add-observability-stack

# Commit 1: Prometheus
git commit -m "feat: add prometheus monitoring setup" ./bootstrap/monitoring/prometheus/

# Commit 2: Grafana
git commit -m "feat: add grafana dashboarding" ./bootstrap/monitoring/grafana/

# Commit 3: Documentation
git commit -m "docs: add observability stack deployment guide" ./docs/observability.md

# All pushed together
git push origin feat/add-observability-stack
```

---

## File Organization

### Structure

```
homelab-argocd/
├── argocd/                          # ArgoCD installation
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── argocd-server.yaml
│   └── argocd-controller.yaml
├── bootstrap/
│   ├── crds/                        # Custom Resource Definitions
│   │   ├── kustomization.yaml
│   │   ├── gateway-api-crds.yaml
│   │   └── envoy-gateway-crds.yaml
│   ├── storage/                     # StorageClasses
│   │   ├── kustomization.yaml
│   │   └── default-storageclass.yaml
│   ├── gateway-api/                 # Gateway API config
│   │   ├── kustomization.yaml
│   │   └── gatewayclass.yaml
│   ├── envoy-gateway/               # Envoy Gateway
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── rbac.yaml
│   │   └── envoygateway.yaml
│   └── networking/                  # Networking config
│       ├── kustomization.yaml
│       ├── metallb-config.yaml
│       └── networkpolicies.yaml
├── docs/
│   ├── setup.md
│   ├── architecture.md
│   ├── troubleshooting.md
│   └── maintenance.md
├── ARGOCD_STRATEGIES_GUIDE.md       # Reference (can be moved to docs/ later)
└── README.md
```

### File Naming Rules

- Use lowercase with hyphens (not underscores)
- Descriptive names indicating purpose
- Consistency across components

**Good examples:**

```
metallb-config.yaml
networkpolicies.yaml
envoygateway-default.yaml
postgres-storageclass.yaml
```

**Bad examples:**

```
config.yaml                          # Too generic
MetallbConfig.yaml                   # Wrong case
metallb_config.yaml                  # Wrong separator
```

---

## Code Style & Best Practices

### YAML/Kubernetes Manifests

1. **Version Pinning:**

   ```yaml
   # ✅ GOOD - exact version
   image: envoyproxy/envoy-gateway:v1.5.0

   # ❌ BAD - unpredictable
   image: envoyproxy/envoy-gateway:latest
   image: envoyproxy/envoy-gateway:v1.5
   ```

2. **Labels and Annotations:**

   ```yaml
   metadata:
     labels:
       app: envoy-gateway
       version: v1.5.0
       managed-by: argocd
     annotations:
       description: "Envoy Gateway operator"
   ```

3. **Resource Limits:**

   ```yaml
   resources:
     requests:
       cpu: 250m
       memory: 256Mi
     limits:
       cpu: 500m
       memory: 512Mi
   ```

4. **Comments for non-obvious choices:**

   ```yaml
   # Why we set this specific replicas count
   replicas: 3 # High availability, fault tolerance

   # Version reasoning
   image: postgres:15-alpine # v15 used, alpine for minimal size
   ```

### Kustomize

1. **Base + Overlays pattern:**

   ```
   component/
   ├── base/
   │   ├── kustomization.yaml
   │   ├── deployment.yaml
   │   └── service.yaml
   └── overlays/
       ├── production/
       │   ├── kustomization.yaml
       │   └── patches.yaml
       └── staging/
           ├── kustomization.yaml
           └── patches.yaml
   ```

2. **Validation before commit:**

   ```bash
   kustomize build bootstrap/ | kubectl apply --dry-run=client -f -
   ```

3. **Never manually edit generated resources**

### Documentation

1. **Every component needs explanation:**
   - What it does
   - Why we use it
   - How to troubleshoot it

2. **Code comments:**
   - Explain WHY, not WHAT (code shows what)
   - Reference links to official docs
   - Call out version-specific behavior

3. **README files:**
   - Main README explains the project
   - Component READMEs explain component purpose
   - docs/ folder has detailed guides

---

## ArgoCD Best Practices

### Repo Structure for ArgoCD Sync

1. **Clear structure:**

   ```
   bootstrap/           # Top level - ArgoCD path
   ├── crds/           # Applied first
   ├── storage/
   ├── networking/
   └── envoy-gateway/
   ```

2. **Dependencies handled by:**
   - Folder ordering (CRDs before operators)
   - syncPolicy in ArgoCD Application
   - Explicit namespace creation

3. **No manual kubectl:**
   - All changes through Git + ArgoCD
   - ArgoCD is source of truth
   - Cluster state ← Git state

### When to Update This Repository

- ✅ Adding new bootstrap components
- ✅ Updating component versions
- ✅ Fixing configuration bugs
- ✅ Adding documentation
- ✅ Refactoring for clarity
- ❌ Don't use for storing application configs (that's separate)

---

## Workflow Checklist

Before pushing, verify:

- [ ] On a feature branch (not main)
- [ ] Branch name follows `type/description` format
- [ ] All manifests have pinned versions
- [ ] Manifests validate: `kustomize build bootstrap/ | kubectl apply --dry-run=client -f -`
- [ ] Commit message follows conventional commits
- [ ] Documentation updated if needed
- [ ] Tested in staging if infrastructure change
- [ ] No secrets committed (no passwords, keys, tokens)
- [ ] Files named with lowercase and hyphens
- [ ] Ready to create PR

---

## Learning Notes

This section documents things we learn about the project that should influence future development:

### Things We Know Work Well

- (To be filled in as project matures)

### Gotchas and Lessons Learned

- (To be filled in as we encounter issues)

### Patterns to Follow

- (Best practices discovered through development)

### Patterns to Avoid

- (Anti-patterns we've learned to avoid)

---

## Questions for the Future

As the project evolves, these are questions to revisit:

1. Should we add a Kustomization resource for ArgoCD to use instead of direct path sync?
2. Should we implement ApplicationSets for multi-environment deployments?
3. Should we split into multi-repo structure if we exceed 20 bootstrap components?
4. Should we add a local development environment for testing before deployment?
5. What observability/monitoring should we add to the bootstrap itself?

---

## Getting Help

If unclear about:

1. **Workflow:** Review this file's Development Workflow section
2. **Git Commands:** Check the Commit Examples section
3. **Project Structure:** See File Organization section
4. **Best Practices:** Refer to Best Practices section
5. **Troubleshooting:** See docs/troubleshooting.md

---

**Last Updated:** February 2026
**Version:** 1.0
**Status:** Initial setup - will evolve based on actual project needs
