# Maintenance & Updates

This document covers version management, upgrading components, and keeping the cluster up-to-date.

## Version Management Philosophy

**Goal:** Reproducibility through version pinning.

**Strategy:**

- All versions pinned explicitly in manifests
- Regular review cycle (monthly suggested)
- Test updates in staging before production
- Document all version changes in commit messages
- Use conventional commits for tracking changes

## Checking Current Versions

### What versions are deployed?

```bash
# Container images
kubectl get deployment -A -o jsonpath='{.items[*].spec.template.spec.containers[*].image}' | tr ' ' '\n' | sort -u

# Helm chart versions (if applicable)
kubectl describe chart <chart-name> -n <namespace>

# CRD API versions in use
kubectl api-resources
```

### Version information in this repo

Check each component's manifests:

```bash
# ArgoCD version
cat argocd/argocd-deployment.yaml | grep image

# Envoy Gateway version
cat bootstrap/envoy-gateway/deployment.yaml | grep image

# Gateway API CRDs (version in CRD apiVersion field)
grep "apiVersion:" bootstrap/gateway-api/crds.yaml
```

## Updating Components

### Step 1: Plan the Update

1. **Check release notes:**
   - <https://github.com/argoproj/argo-cd/releases>
   - <https://github.com/envoyproxy/gateway/releases>
   - <https://github.com/kubernetes-sigs/gateway-api/releases>

2. **Identify breaking changes:**
   - API changes requiring CRD updates?
   - Deprecated configuration options?
   - Required migration steps?

3. **Test in staging first!**
   - Create staging branch: `git checkout -b chore/test-upgrade-envoy-gateway-v1-5`
   - Update manifests
   - Deploy to staging cluster
   - Verify functionality
   - Only then merge to main

### Step 2: Update Manifests

**Example: Updating Envoy Gateway**

1. Find current version:

   ```bash
   grep -n "envoyproxy/envoy-gateway" bootstrap/envoy-gateway/*.yaml
   ```

2. Update image reference:

   ```yaml
   # OLD:
   image: envoyproxy/envoy-gateway:v1.2.3

   # NEW:
   image: envoyproxy/envoy-gateway:v1.5.0
   ```

3. Check for CRD updates:

   ```bash
   # Download new CRDs from release
   curl https://raw.githubusercontent.com/envoyproxy/gateway/v1.5.0/api/config/v1alpha1/crd.yaml -o bootstrap/crds/envoy-gateway-crds-v1.5.0.yaml

   # Compare with old version
   diff bootstrap/crds/envoy-gateway-crds-v1.2.3.yaml bootstrap/crds/envoy-gateway-crds-v1.5.0.yaml

   # Remove old version
   rm bootstrap/crds/envoy-gateway-crds-v1.2.3.yaml
   ```

### Step 3: Test Update

```bash
# Validate manifests
kustomize build bootstrap/ | kubectl apply --dry-run=client -f -

# Deploy to staging
git checkout -b chore/upgrade-envoy-gateway-v1.5
git add bootstrap/
git commit -m "chore: upgrade envoy-gateway from v1.2.3 to v1.5.0

- Updated deployment image
- Updated CRDs
- No breaking changes in v1.5
- Tested on staging cluster"

git push origin chore/upgrade-envoy-gateway-v1.5
# Create PR and merge after testing
```

### Step 4: Deploy to Production

Once merged to main:

```bash
# ArgoCD will automatically sync within 3 minutes (or manually trigger)
kubectl rollout status deployment/envoy-gateway -n envoy-gateway-system

# Verify upgrade successful
kubectl get pod -n envoy-gateway-system -o jsonpath='{.items[*].spec.containers[*].image}'
```

## Scheduled Update Cycle

**Recommended:** Monthly security and patch updates

### Update Calendar

```
1st Monday of month: Check for critical security updates
2nd Monday of month: Review non-security patch updates
3rd Monday of month: Test updates on staging
4th Monday of month: Deploy to production (if no issues found)
```

### Which Updates to Prioritize

1. **Security Updates (highest priority)**
   - Deploy to staging immediately
   - Fast-track to production if no issues

2. **Bug Fixes (high priority)**
   - Fix important bugs affecting your use case
   - Schedule in normal cycle

3. **Minor Updates (medium priority)**
   - New features you might use
   - Include in monthly cycle

4. **Major Updates (plan ahead)**
   - Plan ahead for breaking changes
   - Test extensively before deploying

## Common Update Scenarios

### Scenario 1: Update ArgoCD

```bash
# Create branch
git checkout main && git pull
git checkout -b chore/upgrade-argocd-v2-10

# Find current version
grep "quay.io/argoproj/argocd" argocd/argocd-*.yaml

# Update version (e.g., v2.10.0 -> v2.11.0)
sed -i 's/v2.10.0/v2.11.0/g' argocd/argocd-*.yaml

# Commit
git commit -m "chore: upgrade argocd from v2.10.0 to v2.11.0"

# Test, then push and create PR
```

### Scenario 2: Update StorageClass

```bash
# Create branch
git checkout main && git pull
git checkout -b feat/add-high-performance-storage

# Add new StorageClass
cat >> bootstrap/storage/storageclasses.yaml << 'EOF'
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: high-performance
provisioner: your-provisioner
parameters:
  iops: "5000"
EOF

# Commit with descriptive message
git commit -m "feat: add high-performance StorageClass

- New StorageClass for performance-sensitive workloads
- 5000 IOPS configuration
- Provisioner: your-provisioner"

# Test on staging first!
```

### Scenario 3: Update Envoy Gateway CRDs

```bash
# If EnvoyGateway API changed, you may need to update configs:

git checkout main && git pull
git checkout -b chore/update-envoy-gateway-crd-v1.6

# Update CRD
curl https://raw.githubusercontent.com/envoyproxy/gateway/v1.6.0/config/crd/core_gateway.yaml -o bootstrap/gateway-api/envoy-gateway-crd-v1.6.0.yaml

# Update default EnvoyGateway resource if needed
# Review bootstrap/envoy-gateway/envoygateway.yaml

git add bootstrap/
git commit -m "chore: update envoy-gateway crds to v1.6.0"
```

## Monitoring for Updates

### Automated Update Notifications

Option 1: GitHub Dependabot

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

Option 2: Manual checks

```bash
# Create a monthly reminder
# Check for updates at: https://github.com/
# - argoproj/argo-cd/releases
# - envoyproxy/gateway/releases
# - kubernetes-sigs/gateway-api/releases
```

## Rollback Procedure

If an update causes issues:

### Quick Rollback (within 5 minutes)

```bash
# Git revert the last commit
git revert HEAD

# ArgoCD syncs automatically, cluster reverts
# This is the beauty of GitOps!
```

### Documented Rollback

```bash
# Create explicit rollback branch
git checkout main
git pull
git checkout -b fix/rollback-envoy-gateway-from-v1.5

# Downgrade version in manifests
sed -i 's/v1.5.0/v1.2.3/g' bootstrap/envoy-gateway/*.yaml

# Document why
git commit -m "fix: rollback envoy-gateway from v1.5.0 to v1.2.3

REASON: v1.5.0 caused performance issues with high connection count
- Will revisit after investigating root cause
- v1.2.3 was stable for our workload
- Issue ticket: #123"

git push origin fix/rollback-envoy-gateway-from-v1.5
# Create PR, review, merge
```

## Tracking Update History

All updates are tracked in Git history:

```bash
# See all version updates
git log --grep="chore:" --oneline | head -20

# See specific component updates
git log --grep="envoy-gateway" --oneline

# See when a version was deployed
git log -p -- bootstrap/envoy-gateway/ | grep "image:"
```

## Best Practices

1. ✅ **Always test staging first** before production
2. ✅ **Commit every change** - use conventional commits
3. ✅ **Document breaking changes** in commit message body
4. ✅ **Pin exact versions** - never use "latest"
5. ✅ **Review release notes** - check for deprecations
6. ✅ **Keep CRDs in sync** - update CRDs before operators
7. ✅ **Have a rollback plan** - document it before updating
8. ✅ **Communicate changes** - notify team before updates

## Anti-patterns (What NOT to do)

1. ❌ **Don't use `latest` tag** - breaks reproducibility
2. ❌ **Don't update multiple components at once** - hard to debug
3. ❌ **Don't skip staging** - test in staging first
4. ❌ **Don't commit directly to main** - always use branches
5. ❌ **Don't delete old versions** - keep for reference/rollback
6. ❌ **Don't forget to test** - lazy testing = production outages

## Support

For issues with updates:

1. Check [Troubleshooting Guide](troubleshooting.md)
2. Review commit message that introduced the update
3. Check component release notes for known issues
4. Revert to previous version if needed
