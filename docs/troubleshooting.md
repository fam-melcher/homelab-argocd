# Troubleshooting Guide

Common issues and solutions when bootstrapping clusters with this repository.

## ArgoCD Issues

### ArgoCD pods not starting

**Symptom:** `kubectl get pods -n argocd` shows pods in Pending or CrashLoopBackOff

**Check resources:**

```bash
kubectl describe pod <pod-name> -n argocd
```

**Common causes:**

1. **Storage not available:** PersistentVolumeClaims cannot be bound
   - Solution: Verify storage provisioner is available in cluster

2. **Resource limits:** Node doesn't have enough CPU/memory
   - Solution: Check node resources with `kubectl top nodes`

3. **Image pull issues:** Can't pull ArgoCD image
   - Solution: Check image registry access, verify internet connectivity

### ArgoCD not syncing application

**Symptom:** Application shows "OutOfSync" or status is pending

**Check application status:**

```bash
kubectl describe application bootstrap -n argocd

# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Check ArgoCD API server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

**Common causes:**

1. **Repository access denied**
   - Check: SSH key or HTTP credentials configured in ArgoCD
   - Solution: Verify repository credentials in ArgoCD settings

2. **Git reference doesn't exist**
   - Check: targetRevision (main branch exists)
   - Solution: Verify branch name in Application spec

3. **Manifest errors in repository**
   - Check: Kustomize build succeeds locally
   - Solution: Run `kustomize build bootstrap/` locally to verify

### Can't access ArgoCD web UI

**Forward port:**

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

**URL:** `https://localhost:8080`

**Get default password:**

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

## Bootstrap Component Issues

### Kairos NodeOp CRD not registered

**Symptom:** `Error: unable to recognize nodeop-crd.yaml: no matches for kind "NodeOp"`

**Solution:**

```bash
# Check if CRD is installed
kubectl get crd nodeop.kairos.io

# If not present, verify bootstrap/crds/ manifests deployed
kubectl get application bootstrap -n argocd -o yaml | grep crds

# Force resync if needed
argocd app sync bootstrap
```

### K3s configuration not applying

**Symptom:** K3s API server settings not reflected in cluster

**Debug:**

```bash
# Check K3s node operator logs
kubectl logs -n kube-system -l app=k3s-node-operator -f

# Verify NodeOp resource deployed
kubectl get nodeop

# Check NodeOp status
kubectl describe nodeop configure-kube-apiserver

# View K3s systemd service
kubectl debug node/<node-name> -it -- chroot /host systemctl status k3s
```

### Pod Security policies not enforced

**Symptom:** Pods running with elevated privileges when policy is restrictive

**Debug:**

```bash
# Verify pod security policy deployed
kubectl get nodeop k3s-pod-security -o yaml

# Check if admission plugin is configured
kubectl debug node/<node-name> -it -- chroot /host grep -i "pod-security" /etc/systemd/system/k3s.service

# Try deploying a privileged pod to test enforcement
kubectl run test --image=alpine -- sleep 1000 --privileged
# Should fail if policy is restrictive

# Check pod security audit logs
kubectl logs -n kube-system -l component=kubelet
```

## CRD and API Issues

### CRD validation errors

**Symptom:** `error: validation failure`

**Debug:**

```bash
# Get detailed error
kubectl apply -f <manifest> --dry-run=server

# Check CRD schema
kubectl get crd <crd-name> -o yaml | grep -A 50 validation

# Validate manifest locally
kustomize build bootstrap/ > /tmp/manifest.yaml
kubeconform -strict /tmp/manifest.yaml
```

### API version conflicts

**Symptom:** `error: apiVersion <api> not found`

**Solution:**

```bash
# List available API versions for a resource type
kubectl api-resources | grep -i nodeop

# Use correct API version in manifests
# Check bootstrap/crds/nodeop-crd.yaml for correct apiVersion

# Verify all CRDs installed
kubectl get crd
```

## General Troubleshooting Steps

### 1. Check ArgoCD application status

```bash
kubectl get applications -n argocd
kubectl describe application bootstrap -n argocd
```

### 2. Review recent events

```bash
kubectl get events -A --sort-by='.lastTimestamp'
```

### 3. Check component logs

```bash
# ArgoCD controller logs
kubectl top nodes
kubectl top pods -A
```

## Getting Help

If stuck:

1. **Check GitOps principles:** Is the desired state in Git?
2. **Check ArgoCD:** Is ArgoCD syncing the Git state?
3. **Check cluster:** Does the cluster match Git?
4. **Review logs:** What do the component logs say?

When reporting issues, include:

- ArgoCD application status
- Recent events (`kubectl get events -A`)
- Relevant pod logs
- What you expected vs. what happened
